# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Cleanup::ExecutePolicyService, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:policy) { create(:virtual_registries_cleanup_policy, group:) }
  let_it_be(:maven_upstream) { create(:virtual_registries_packages_maven_upstream, group:) }
  let_it_be(:container_upstream) { create(:virtual_registries_container_upstream, group:) }
  let_it_be(:local_maven_upstream) do
    create(:virtual_registries_packages_maven_upstream,
      :without_credentials,
      group: group,
      url: group.to_global_id.to_s
    )
  end

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
              maven: { deleted_entries_count: 0, deleted_size: 0 },
              container: { deleted_entries_count: 0, deleted_size: 0 }
            }
          )
        end
      end

      context 'with cache entries requiring cleanup' do
        let!(:old_maven_entry1) do
          create(
            :virtual_registries_packages_maven_cache_entry,
            upstream: maven_upstream,
            size: 1024,
            downloaded_at: 35.days.ago
          )
        end

        let!(:old_maven_entry2) do
          create(
            :virtual_registries_packages_maven_cache_entry,
            upstream: maven_upstream,
            size: 2048,
            downloaded_at: 40.days.ago
          )
        end

        let!(:old_container_entry) do
          create(
            :virtual_registries_container_cache_entry,
            upstream: container_upstream,
            size: 2048,
            downloaded_at: 40.days.ago
          )
        end

        let!(:recent_maven_entry) do
          create(
            :virtual_registries_packages_maven_cache_entry,
            upstream: maven_upstream,
            size: 512,
            downloaded_at: 10.days.ago
          )
        end

        let!(:recent_container_entry) do
          create(
            :virtual_registries_container_cache_entry,
            upstream: container_upstream,
            size: 512,
            downloaded_at: 10.days.ago
          )
        end

        before do
          allow(::VirtualRegistries::CreateAuditEventsService).to receive(:new).and_call_original
        end

        it 'marks old entries for destruction and returns correct counts, and creates audit events',
          :aggregate_failures do
          expect { execute }.to change { maven_upstream.cache_entries.pending_destruction.count }.by(2)
            .and change { container_upstream.cache_entries.pending_destruction.count }.by(1)

          expect_audit_events_for([old_maven_entry1, old_maven_entry2])
          expect_audit_events_for([old_container_entry])

          is_expected.to be_success.and have_attributes(
            payload: {
              maven: { deleted_entries_count: 2, deleted_size: 3072 },
              container: { deleted_entries_count: 1, deleted_size: 2048 }
            }
          )
        end
      end

      context 'with multiple upstreams' do
        let_it_be(:maven_upstream2) { create(:virtual_registries_packages_maven_upstream, group:) }
        let_it_be(:container_upstream2) { create(:virtual_registries_container_upstream, group:) }

        let!(:maven_entry_upstream1) do
          create(
            :virtual_registries_packages_maven_cache_entry,
            upstream: maven_upstream,
            size: 1024,
            downloaded_at: 35.days.ago
          )
        end

        let!(:maven_entry_upstream2) do
          create(
            :virtual_registries_packages_maven_cache_entry,
            upstream: maven_upstream2,
            size: 2048,
            downloaded_at: 40.days.ago
          )
        end

        let!(:container_entry_upstream1) do
          create(
            :virtual_registries_container_cache_entry,
            upstream: container_upstream,
            size: 512,
            downloaded_at: 35.days.ago
          )
        end

        let!(:container_entry_upstream2) do
          create(
            :virtual_registries_container_cache_entry,
            upstream: container_upstream2,
            size: 768,
            downloaded_at: 40.days.ago
          )
        end

        before do
          allow(::VirtualRegistries::CreateAuditEventsService).to receive(:new).and_call_original
        end

        it 'processes entries from all upstreams and creates audit events', :aggregate_failures do
          expect { execute }.to change { maven_upstream.cache_entries.pending_destruction.count }.by(1)
            .and change { maven_upstream2.cache_entries.pending_destruction.count }.by(1)
            .and change { container_upstream.cache_entries.pending_destruction.count }.by(1)
            .and change { container_upstream2.cache_entries.pending_destruction.count }.by(1)

          expect_audit_events_for([maven_entry_upstream1])
          expect_audit_events_for([maven_entry_upstream2])
          expect_audit_events_for([container_entry_upstream1])
          expect_audit_events_for([container_entry_upstream2])

          is_expected.to be_success.and have_attributes(
            payload: {
              maven: { deleted_entries_count: 2, deleted_size: 3072 },
              container: { deleted_entries_count: 2, deleted_size: 1280 }
            }
          )
        end
      end

      context 'with large number of entries' do
        before do
          stub_const("#{described_class}::BATCH_SIZE", 2)

          create_list(
            :virtual_registries_packages_maven_cache_entry, 5,
            upstream: maven_upstream,
            size: 1024,
            downloaded_at: 35.days.ago
          )
        end

        it 'processes all batches', :aggregate_failures do
          expect { execute }.to change { maven_upstream.cache_entries.pending_destruction.count }.by(5)

          is_expected.to be_success.and have_attributes(
            payload: {
              maven: { deleted_entries_count: 5, deleted_size: 5120 },
              container: { deleted_entries_count: 0, deleted_size: 0 }
            }
          )
        end
      end

      context 'when an error occurs' do
        before do
          allow_next_found_instance_of(VirtualRegistries::Packages::Maven::Upstream) do |upstream_instance|
            allow(upstream_instance).to receive(:default_cache_entries).and_raise(StandardError, 'Database error')
          end
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
