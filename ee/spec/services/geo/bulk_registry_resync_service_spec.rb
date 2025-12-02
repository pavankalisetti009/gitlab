# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BulkRegistryResyncService, :geo, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:model_name) { 'Geo::JobArtifactRegistry' }
  let(:params) { {} }
  let(:service) { described_class.new(model_name, params) }
  let(:params_hash) { Base64.urlsafe_encode64(Gitlab::Json.dump(params.deep_stringify_keys)) }
  let(:redis_key) { "geo:job_artifact_registry:#{params_hash}:bulk_registry_resync_service_cursor" }
  let(:registry_class) { model_name.constantize }
  let(:registry_states) { registry_class::STATE_VALUES }

  before do
    stub_current_geo_node(create(:geo_node, :primary))
  end

  describe '#async_execute' do
    it 'enqueues the worker and returns success response' do
      expect(Geo::BulkRegistryResyncWorker).to receive(:perform_async)
                                                      .with(model_name, params.deep_stringify_keys)

      result = service.async_execute

      expect(result).to be_success
      expect(result.message).to eq('Batch update job has been successfully enqueued.')
      expect(result.payload[:status]).to eq(:pending)
    end

    context 'with invalid model_name' do
      let(:model_name) { 'invalid' }

      it 'returns a NotImplemented error' do
        expect(Geo::BulkRegistryResyncWorker).not_to receive(:perform_async)

        expect { service.async_execute }.to raise_error(NotImplementedError, /Cannot find a class for invalid/)
      end
    end
  end

  describe '#execute' do
    before do
      create_list(:geo_job_artifact_registry, 5, :synced)
    end

    context 'when there are records to update' do
      it 'updates replication state of all records to pending' do
        service.execute

        expect(registry_class.pending.size).to eq(5)
        expect(registry_class.synced.size).to eq(0)
      end

      it 'returns success response when completed' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('All records have been successfully updated.')
        expect(result.payload[:status]).to eq(:completed)
      end

      it 'deletes the Redis cursor key on completion' do
        Gitlab::Redis::SharedState.with { |redis| redis.set(redis_key, 99) }

        result = service.execute

        expect(result.payload[:status]).to eq(:completed)
        Gitlab::Redis::SharedState.with do |redis|
          expect(redis.get(redis_key)).to be_nil
        end
      end

      it 'logs completion message' do
        expect(service).to receive(:log_info).with('All records have been successfully updated.')

        service.execute
      end

      it 'processes records in batches' do
        stub_const('Geo::BaseBatchBulkUpdateService::BATCH_SIZE', 2)
        relation = registry_class.not_pending
        allow(registry_class).to receive_message_chain(:not_pending, :after_cursor).and_return(relation)

        expect(relation).to receive(:update_all).exactly(3).times

        service.execute
      end

      context 'with replication_state filters' do
        let(:params) { { replication_state: } }

        shared_examples 'only updates expected records' do
          let!(:expected_records) do
            create_list(:geo_job_artifact_registry, 2, state: registry_states[replication_state])
          end

          it 'updates the expected records' do
            service.execute

            pending_records = registry_class.pending
            expect(pending_records.size).to eq(2)
            expect(pending_records).to match_array(expected_records)
          end
        end

        context 'when filter is failed' do
          let(:replication_state) { :failed }

          it_behaves_like 'only updates expected records'
        end

        context 'when filter is started' do
          let(:replication_state) { :started }

          it_behaves_like 'only updates expected records'
        end

        context 'when filter is succeeded' do
          let(:replication_state) { :synced }

          it 'only updates succeeded records' do
            expected_records = registry_class.all

            service.execute

            pending_records = registry_class.pending
            expect(pending_records.size).to eq(5)
            expect(pending_records).to match_array(expected_records)
          end
        end
      end

      context 'with id filters' do
        let(:params) { { ids: } }
        let!(:ids) { [registry_class.first.id, registry_class.last.id] }

        it 'only updates selected records' do
          expected_records = registry_class.where(id: ids)

          service.execute

          pending_records = registry_class.pending
          expect(pending_records.size).to eq(2)
          expect(pending_records).to match_array(expected_records)
        end
      end

      context 'with id and verification_state filters' do
        let(:params) do
          { ids: [registry_class.first.id, registry_class.last.id], verification_state: :verification_failed }
        end

        it 'only updates matching records' do
          state = Geo::VerificationState::VERIFICATION_STATE_VALUES[:verification_failed]
          registry_class.first.update!(verification_state: state, verification_failure: 'Failed')

          service.execute

          pending_records = registry_class.pending
          expect(pending_records.size).to eq(1)
          expect(pending_records).to contain_exactly(registry_class.first)
        end
      end
    end

    context 'with invalid model_name' do
      let(:model_name) { 'invalid' }

      it 'returns a NotImplemented error' do
        expect(Geo::BulkRegistryResyncWorker).not_to receive(:perform_async)

        expect { service.execute }.to raise_error(NotImplementedError, /Cannot find a class for invalid/)
      end
    end

    context 'when time limit is reached' do
      before do
        # Create multiple records to ensure batching
        create_list(:geo_job_artifact_registry, 5, :synced)
        stub_const('Geo::BaseBatchBulkUpdateService::BATCH_SIZE', 2)

        # Mock runtime limiter to simulate time limit reached
        runtime_limiter = instance_double(Gitlab::Metrics::RuntimeLimiter)
        allow(Gitlab::Metrics::RuntimeLimiter).to receive(:new).and_return(runtime_limiter)
        allow(runtime_limiter).to receive(:over_time?).and_return(false, true) # First batch succeeds, second hits limit
      end

      it 'reenqueues the worker for continuation' do
        expect(Geo::BulkRegistryResyncWorker).to receive(:perform_in)
                                                        .with(described_class::PERFORM_IN,
                                                          model_name,
                                                          params.stringify_keys)

        service.execute
      end

      it 'returns error response with limit_reached status' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to include('20 seconds limit reached on Geo::JobArtifactRegistry update')
        expect(result.payload[:status]).to eq(:limit_reached)
      end

      it 'logs error message' do
        expect(service).to receive(:log_error).with(a_string_including('20 seconds limit reached'))

        service.execute
      end

      it 'saves cursor for continuation' do
        fourth_registry = registry_class.offset(3).first
        expected_cursor = Gitlab::Json.dump(fourth_registry.slice(*registry_class.primary_key).values)

        service.execute

        Gitlab::Redis::SharedState.with do |redis|
          cursor = redis.get(redis_key)
          expect(cursor).to eq(expected_cursor)
        end
      end
    end

    context 'when no records need updating' do
      before do
        # Ensure all records are already pending
        registry_class.update_all(state: 0)
      end

      it 'completes without updating any records' do
        expect { service.execute }.not_to change { registry_class.where(state: registry_states[:pending]).count }
      end

      it 'returns success response' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('All records have been successfully updated.')
        expect(result.payload[:status]).to eq(:completed)
      end
    end

    context 'with cursor continuation' do
      let(:job_artifacts) { create_list(:geo_job_artifact_registry, 3, :synced) }

      before do
        # Set cursor to skip first record
        cursor_value = job_artifacts.first.slice(*job_artifacts.first.class.primary_key).values
        Gitlab::Redis::SharedState.with { |redis| redis.set(redis_key, Gitlab::Json.dump(cursor_value)) }
      end

      it 'continues from cursor position' do
        service.execute

        # First record should remain unchanged, others should be updated
        expect(job_artifacts[0].reload.state).to eq(registry_states[:synced])
        expect(job_artifacts[1].reload.state).to eq(registry_states[:pending])
        expect(job_artifacts[2].reload.state).to eq(registry_states[:pending])
      end
    end
  end

  # Test error handling scenarios
  describe 'error handling' do
    context 'when update_all fails' do
      before do
        create_list(:geo_job_artifact_registry, 3, :synced)

        relation = registry_class.not_pending
        allow(registry_class).to receive_message_chain(:not_pending, :after_cursor).and_return(relation)
        allow(relation).to receive(:update_all).and_raise(ActiveRecord::StatementInvalid, 'Database error')
      end

      it 'allows the exception to bubble up for Sidekiq retry' do
        expect { service.execute }.to raise_error(ActiveRecord::StatementInvalid, 'Database error')
      end
    end

    context 'when last record is nil' do
      before do
        # Mock empty relation
        allow(service).to receive(:records_to_update).and_return(registry_class.none)
      end

      it 'handles empty batches gracefully' do
        expect { service.execute }.not_to raise_error
      end
    end
  end

  describe 'with different model types' do
    where(model_classes: Gitlab::Geo::Replicator.subclasses.map(&:registry_class))

    with_them do
      let(:model_name) { model_classes.name }
      let(:factory) { factory_name(model_classes) }

      it 'updates states' do
        create_list(factory, 3, :synced)

        expect { service.execute }.to change { model_classes.pending.count }.by(3)
      end
    end
  end
end
