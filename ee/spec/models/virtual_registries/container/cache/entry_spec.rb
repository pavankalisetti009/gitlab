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
      it { is_expected.to validate_uniqueness_of(:object_storage_key).scoped_to(:relative_path) }

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
end
