# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::Cache::Entry, feature_category: :virtual_registry do
  subject(:cache_entry) { build(:virtual_registries_container_cache_entry) }

  describe 'validations' do
    %i[group file file_sha1 relative_path size].each do |attr|
      it { is_expected.to validate_presence_of(attr) }
    end

    %i[upstream_etag content_type].each do |attr|
      it { is_expected.to validate_length_of(attr).is_at_most(255) }
    end

    %i[relative_path object_storage_key].each do |attr|
      it { is_expected.to validate_length_of(attr).is_at_most(1024) }
    end

    it { is_expected.to validate_length_of(:file_md5).is_equal_to(32).allow_nil }
    it { is_expected.to validate_length_of(:file_sha1).is_equal_to(40) }

    context 'with persisted cached response' do
      before do
        cache_entry.save!
      end

      it { is_expected.to validate_uniqueness_of(:relative_path).scoped_to(:upstream_id, :status) }
      it { is_expected.to validate_uniqueness_of(:object_storage_key).scoped_to(:relative_path, :group_id) }

      context 'with a similar cached response in a different status' do
        let!(:cache_entry_in_error) do
          create(
            :virtual_registries_container_cache_entry,
            :error,
            group_id: cache_entry.group_id,
            upstream_id: cache_entry.upstream_id,
            relative_path: cache_entry.relative_path
          )
        end

        let(:new_cache_entry) do
          build(
            :virtual_registries_container_cache_entry,
            :error,
            group_id: cache_entry.group_id,
            upstream_id: cache_entry.upstream_id,
            relative_path: cache_entry.relative_path
          )
        end

        it 'does not validate uniqueness of relative_path' do
          new_cache_entry.validate
          expect(new_cache_entry.errors.messages_for(:relative_path)).not_to include 'has already been taken'
        end
      end
    end
  end

  describe 'associations' do
    it 'belongs to an upstream' do
      is_expected.to belong_to(:upstream)
        .class_name('VirtualRegistries::Container::Upstream')
        .required
        .inverse_of(:cache_entries)
    end
  end

  describe 'scopes' do
    describe '.requiring_cleanup' do
      let(:n_days_to_keep) { 30 }
      let_it_be(:old_downloaded_entry) do
        create(:virtual_registries_container_cache_entry).tap do |entry|
          entry.update_column(:downloaded_at, 35.days.ago)
        end
      end

      let_it_be(:recent_downloaded_entry) do
        create(:virtual_registries_container_cache_entry).tap do |entry|
          entry.update_column(:downloaded_at, 25.days.ago)
        end
      end

      subject { described_class.requiring_cleanup(n_days_to_keep) }

      it { is_expected.to include(old_downloaded_entry).and not_include(recent_downloaded_entry) }
    end

    describe '.order_created_desc' do
      let_it_be(:oldest_entry) { create(:virtual_registries_container_cache_entry, created_at: 3.days.ago) }
      let_it_be(:newest_entry) { create(:virtual_registries_container_cache_entry, created_at: 1.day.ago) }
      let_it_be(:middle_entry) { create(:virtual_registries_container_cache_entry, created_at: 2.days.ago) }

      subject { described_class.order_created_desc }

      it { is_expected.to eq([newest_entry, middle_entry, oldest_entry]).and be_a(ActiveRecord::Relation) }

      context 'when no records exist' do
        before do
          described_class.delete_all
        end

        it { is_expected.to be_empty.and be_a(ActiveRecord::Relation) }
      end
    end

    describe '.search_by_relative_path' do
      let_it_be(:cache_entry) do
        create(:virtual_registries_container_cache_entry, relative_path: 'path/to/resource')
      end

      let_it_be(:other_cache_entry) do
        create(:virtual_registries_container_cache_entry, relative_path: 'other/path')
      end

      subject { described_class.search_by_relative_path(relative_path) }

      context 'with a matching relative path' do
        let(:relative_path) { 'resource' }

        it { is_expected.to contain_exactly(cache_entry) }
      end
    end
  end

  describe 'object storage key' do
    it 'can not be null' do
      cache_entry.object_storage_key = nil
      cache_entry.relative_path = nil
      cache_entry.upstream = nil

      expect(cache_entry).to be_invalid
      expect(cache_entry.errors.full_messages).to include("Object storage key can't be blank")
    end

    it 'can not be too large' do
      cache_entry.object_storage_key = 'a' * 1025
      cache_entry.relative_path = nil

      expect(cache_entry).to be_invalid
      expect(cache_entry.errors.full_messages)
        .to include('Object storage key is too long (maximum is 1024 characters)')
    end

    it 'is set before saving' do
      expect { cache_entry.save! }
        .to change { cache_entry.object_storage_key }.from(nil).to(an_instance_of(String))
    end

    context 'with a persisted cached response' do
      let(:key) { cache_entry.object_storage_key }

      before do
        cache_entry.save!
      end

      it 'does not change after an update' do
        expect(key).to be_present

        cache_entry.update!(
          file: CarrierWaveStringFile.new('test'),
          size: 2.kilobytes
        )

        expect(cache_entry.object_storage_key).to eq(key)
      end

      it 'is read only' do
        expect(key).to be_present

        cache_entry.object_storage_key = 'new-key'
        cache_entry.save!

        expect(cache_entry.reload.object_storage_key).to eq(key)
      end
    end
  end

  context 'with loose foreign key on virtual_registries_container_cache_entries.upstream_id' do
    it_behaves_like 'update by a loose foreign key' do
      let_it_be(:parent) { create(:virtual_registries_container_upstream) }
      let_it_be(:model) { create(:virtual_registries_container_cache_entry, upstream: parent) }

      let(:find_model) { described_class.last }
    end
  end

  describe '.create_or_update_by!' do
    let_it_be(:upstream) { create(:virtual_registries_container_upstream) }
    let_it_be(:group) { create(:group) }

    let(:relative_path) { '/test/path' }
    let(:updates) { { file_sha1: 'da39a3ee5e6b4b0d3255bfef95601890afd80709' } }

    let(:size) { 10.bytes }

    subject(:create_or_update) do
      Tempfile.create('test.txt') do |file|
        file.write('test')
        described_class.create_or_update_by!(
          upstream: upstream,
          group_id: upstream.group_id,
          relative_path: '/test',
          updates: { file: file, size: size, file_sha1: '4e1243bd22c66e76c2ba9eddc1f91394e57f9f95' }
        )
      end
    end

    context 'with parallel execution' do
      it 'creates or update the existing record' do
        expect { with_threads { create_or_update } }.to change { described_class.count }.by(1)
      end
    end

    context 'with invalid updates' do
      let(:size) { nil }

      it 'bubbles up the error' do
        expect { create_or_update }.to not_change { described_class.count }
          .and raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '#filename' do
    let(:cache_entry) { build(:virtual_registries_container_cache_entry) }

    subject { cache_entry.filename }

    it { is_expected.to eq(File.basename(cache_entry.relative_path)) }

    context 'when relative_path is nil' do
      before do
        cache_entry.relative_path = nil
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#bump_downloads_count' do
    let_it_be(:cache_entry) { create(:virtual_registries_container_cache_entry) }

    subject(:bump) { cache_entry.bump_downloads_count }

    it 'enqueues the update', :sidekiq_inline do
      expect(FlushCounterIncrementsWorker)
        .to receive(:perform_in)
        .with(Gitlab::Counters::BufferedCounter::WORKER_DELAY, described_class.name, cache_entry.id, 'downloads_count')
        .and_call_original

      expect { bump }.to change { cache_entry.reload.downloads_count }.by(1)
        .and change { cache_entry.downloaded_at }
    end
  end

  def with_threads(count: 5, &block)
    return unless block

    # create a race condition - structure from https://blog.arkency.com/2015/09/testing-race-conditions/
    wait_for_it = true

    threads = Array.new(count) do
      Thread.new do
        # each thread must checkout its own connection
        ApplicationRecord.connection_pool.with_connection do
          # A loop to make threads busy until we `join` them
          true while wait_for_it

          yield
        end
      end
    end

    wait_for_it = false
    threads.each(&:join)
  end
  describe '#mark_as_pending_destruction' do
    let(:cache_entry) { create(:virtual_registries_container_cache_entry) }

    subject(:execute) { cache_entry.mark_as_pending_destruction }

    shared_examples 'updating the status and relative_path properly' do
      it 'updates the status and relative_path' do
        previous_path = cache_entry.relative_path

        expect { execute }.to change { cache_entry.status }.from('default').to('pending_destruction')
          .and not_change { cache_entry.object_storage_key }

        expect(cache_entry.relative_path).to start_with("#{previous_path}/deleted/")
      end
    end

    it_behaves_like 'updating the status and relative_path properly'

    context 'with an existing pending destruction record with same relative_path and upstream_id' do
      before do
        create(
          :virtual_registries_container_cache_entry,
          :pending_destruction,
          upstream: cache_entry.upstream,
          relative_path: cache_entry.relative_path
        )
      end

      it_behaves_like 'updating the status and relative_path properly'
    end
  end
end
