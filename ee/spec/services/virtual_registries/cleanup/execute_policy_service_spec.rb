# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Cleanup::ExecutePolicyService, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:policy) { create(:virtual_registries_cleanup_policy, group:) }

  let(:service) { described_class.new(policy) }

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when policy is nil' do
      let(:policy) { nil }

      it { is_expected.to be_error }
    end

    context 'when policy exists' do
      context 'with no cache entries' do
        it 'returns success with zero counts' do
          is_expected.to be_success.and have_attributes(
            payload: {
              maven: { deleted_entries_count: 0, deleted_size: 0 }
            }
          )
        end
      end

      context 'with cache entries requiring cleanup' do
        let!(:old_maven_entry1) do
          create(
            :virtual_registries_packages_maven_cache_remote_entry,
            group: group,
            size: 1024,
            downloaded_at: 35.days.ago
          )
        end

        let!(:old_maven_entry2) do
          create(
            :virtual_registries_packages_maven_cache_remote_entry,
            group: group,
            size: 2048,
            downloaded_at: 40.days.ago
          )
        end

        let!(:recent_maven_entry) do
          create(
            :virtual_registries_packages_maven_cache_remote_entry,
            group: group,
            size: 512,
            downloaded_at: 10.days.ago
          )
        end

        before do
          allow(::VirtualRegistries::CreateAuditEventsService).to receive(:new).and_call_original
        end

        it 'marks old entries for destruction and returns correct counts, and creates audit events',
          :aggregate_failures do
          expect { execute }.to change {
            ::VirtualRegistries::Packages::Maven::Cache::Remote::Entry.for_group(group).pending_destruction.size
          }.by(2)

          expect_audit_events_for([old_maven_entry1, old_maven_entry2])

          is_expected.to be_success.and have_attributes(
            payload: {
              maven: { deleted_entries_count: 2, deleted_size: 3072 }
            }
          )
        end
      end

      context 'with large number of entries' do
        before do
          stub_const("#{described_class}::BATCH_SIZE", 2)

          create_list(
            :virtual_registries_packages_maven_cache_remote_entry, 5,
            group: group,
            size: 1024,
            downloaded_at: 35.days.ago
          )
        end

        it 'processes all batches', :aggregate_failures do
          expect { execute }.to change {
            ::VirtualRegistries::Packages::Maven::Cache::Remote::Entry.for_group(group).pending_destruction.size
          }.by(5)

          is_expected.to be_success.and have_attributes(
            payload: {
              maven: { deleted_entries_count: 5, deleted_size: 5120 }
            }
          )
        end
      end

      context 'when an error occurs' do
        before do
          allow(::VirtualRegistries::Packages::Maven::Cache::Remote::Entry).to receive(:default)
            .and_raise(StandardError, 'Database error')
        end

        it { is_expected.to be_error.and have_attributes(message: /Database error/) }
      end
    end

    def expect_audit_events_for(entries)
      expect(::VirtualRegistries::CreateAuditEventsService).to have_received(:new).once
        .with(entries: entries, event_name: "#{entries.first.model_name.param_key}_deleted")
    end
  end
end
