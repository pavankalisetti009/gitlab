# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BulkPrimaryVerificationService, :geo, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:model_name) { 'Upload' }
  let(:params) { {} }
  let(:service) { described_class.new(model_name, params) }

  before do
    stub_current_geo_node(create(:geo_node, :primary))
  end

  describe '#async_execute' do
    it 'enqueues the worker and returns success response' do
      expect(Geo::BulkPrimaryVerificationWorker).to receive(:perform_async)
                                                      .with(model_name, params.deep_stringify_keys)

      result = service.async_execute

      expect(result).to be_success
      expect(result.message).to eq('Batch update job has been successfully enqueued.')
      expect(result.payload[:status]).to eq(:pending)
    end

    context 'with invalid model_name' do
      let(:model_name) { 'invalid' }

      it 'returns and log an error' do
        expect(Geo::BulkPrimaryVerificationWorker).not_to receive(:perform_async)

        result = service.async_execute

        expect(result).to be_error
        expect(result.message).to eq("No table found from invalid")
        expect(result.payload[:status]).to eq(:failed)
      end
    end
  end

  describe '#execute' do
    let_it_be(:redis_key) { 'geo:upload_states:bulk_primary_verification_service_cursor' }

    before do
      create_list(:upload, 5, :verification_succeeded)
    end

    context 'when there are records to update' do
      it 'updates verification state of all records to pending' do
        service.execute

        expect(Upload.verification_pending.size).to eq(5)
        expect(Upload.verification_succeeded.size).to eq(0)
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
        relation = ::Geo::UploadState.verification_state_not_pending
        allow(::Geo::UploadState).to receive_message_chain(:verification_state_not_pending, :after_cursor)
                                       .and_return(relation)

        expect(relation).to receive(:update_all).exactly(3).times

        service.execute
      end

      context 'with checksum_state filters' do
        let(:params) { { checksum_state: } }

        context 'when filter is failed' do
          let(:checksum_state) { 'verification_failed' }

          it 'only updates failed records' do
            expected_records = create_list(:upload, 2, :verification_failed)

            service.execute

            pending_records = Upload.verification_pending
            expect(pending_records.size).to eq(2)
            expect(pending_records).to match_array(expected_records)
          end
        end

        context 'when filter is succeeded' do
          let(:checksum_state) { 'verification_succeeded' }

          it 'only updates succeeded records' do
            expected_records = Upload.all

            service.execute

            pending_records = Upload.verification_pending
            expect(pending_records.size).to eq(5)
            expect(pending_records).to match_array(expected_records)
          end
        end

        context 'when filter is disabled' do
          let(:checksum_state) { 'verification_disabled' }

          it 'only updates disabled records' do
            expected_records = create_list(:upload,
              2,
              verification_state: Upload.verification_state_value(checksum_state))

            service.execute

            pending_records = Upload.verification_pending
            expect(pending_records.size).to eq(2)
            expect(pending_records).to match_array(expected_records)
          end
        end

        context 'when filter is started' do
          let(:checksum_state) { 'verification_started' }

          it 'only updates started records' do
            expected_records = create_list(:upload,
              2,
              verification_state: Upload.verification_state_value(checksum_state))

            service.execute

            pending_records = Upload.verification_pending
            expect(pending_records.size).to eq(2)
            expect(pending_records).to match_array(expected_records)
          end
        end
      end

      context 'with id filters' do
        let(:params) { { identifiers: } }
        let!(:identifiers) { [Upload.first.verification_state_object.id, Upload.last.verification_state_object.id] }

        it 'only updates selected records' do
          expected_records = Upload.where(id: identifiers)

          service.execute

          pending_records = Upload.verification_pending
          expect(pending_records.size).to eq(2)
          expect(pending_records).to match_array(expected_records)
        end
      end

      context 'with id and state filters' do
        let(:params) do
          { identifiers: [Upload.first.verification_state_object.id, Upload.last.verification_state_object.id],
            checksum_state: :verification_failed }
        end

        before do
          Upload.first.verification_failed_with_message!('error', StandardError.new('some error'))
        end

        it 'only updates matching records' do
          expected_records = [Upload.first]

          service.execute

          pending_records = Upload.verification_pending
          expect(pending_records.size).to eq(1)
          expect(pending_records).to match_array(expected_records)
        end
      end
    end

    context 'with invalid model_name' do
      let(:model_name) { 'invalid' }

      it 'returns and log an error' do
        expect(Geo::BulkPrimaryVerificationWorker).not_to receive(:perform_async)

        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq("No table found from invalid")
        expect(result.payload[:status]).to eq(:failed)
      end
    end

    context 'when time limit is reached' do
      before do
        # Create multiple records to ensure batching
        create_list(:upload, 5, :verification_succeeded)
        stub_const('Geo::BaseBatchBulkUpdateService::BATCH_SIZE', 2)

        # Mock runtime limiter to simulate time limit reached
        runtime_limiter = instance_double(Gitlab::Metrics::RuntimeLimiter)
        allow(Gitlab::Metrics::RuntimeLimiter).to receive(:new).and_return(runtime_limiter)
        allow(runtime_limiter).to receive(:over_time?).and_return(false, true) # First batch succeeds, second hits limit
      end

      it 'reenqueues the worker for continuation' do
        expect(Geo::BulkPrimaryVerificationWorker).to receive(:perform_in)
                                                        .with(10.seconds, model_name, params.stringify_keys)

        service.execute
      end

      it 'returns error response with limit_reached status' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to include('20 seconds limit reached on Geo::UploadState update')
        expect(result.payload[:status]).to eq(:limit_reached)
      end

      it 'logs error message' do
        expect(service).to receive(:log_error).with(a_string_including('20 seconds limit reached'))

        service.execute
      end

      it 'saves cursor for continuation' do
        fourth_upload_state = Upload.offset(3).first.upload_state
        expected_cursor = Gitlab::Json.dump(fourth_upload_state.slice(*fourth_upload_state.class.primary_key).values)

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
        Geo::UploadState.update_all(verification_state: 0)
      end

      it 'completes without updating any records' do
        expect { service.execute }.not_to change { Geo::UploadState.where(verification_state: 0).count }
      end

      it 'returns success response' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('All records have been successfully updated.')
        expect(result.payload[:status]).to eq(:completed)
      end
    end

    context 'with cursor continuation' do
      let(:uploads) { create_list(:upload, 3, :verification_succeeded) }

      before do
        # Set cursor to skip first record
        cursor_value = uploads.first.slice(*uploads.first.class.primary_key).values
        Gitlab::Redis::SharedState.with { |redis| redis.set(redis_key, Gitlab::Json.dump(cursor_value)) }
      end

      it 'continues from cursor position' do
        service.execute

        # First record should remain unchanged, others should be updated
        expect(uploads[0].reload.verification_state).to eq(2)
        expect(uploads[1].reload.verification_state).to eq(0)
        expect(uploads[2].reload.verification_state).to eq(0)
      end
    end
  end

  # Test error handling scenarios
  describe 'error handling' do
    context 'when update_all fails' do
      before do
        create_list(:upload, 3, :verification_succeeded)

        relation = ::Geo::UploadState.verification_state_not_pending
        allow(::Geo::UploadState).to receive_message_chain(:verification_state_not_pending, :after_cursor)
                                       .and_return(relation)
        allow(relation).to receive(:update_all).and_raise(ActiveRecord::StatementInvalid, 'Database error')
      end

      it 'allows the exception to bubble up for Sidekiq retry' do
        expect { service.execute }.to raise_error(ActiveRecord::StatementInvalid, 'Database error')
      end
    end

    context 'when last record is nil' do
      before do
        # Mock empty relation
        allow(service).to receive(:records_to_update).and_return(Geo::UploadState.none)
      end

      it 'handles empty batches gracefully' do
        expect { service.execute }.not_to raise_error
      end
    end
  end

  describe 'with different model types' do
    where(model_classes: Gitlab::Geo::Replicator.subclasses.map(&:model))

    with_them do
      let(:model_name) { model_classes.name }
      let(:factory) { factory_name(model_classes) }

      it 'updates verification states' do
        create_list(factory, 3, :verification_succeeded)

        expect { service.execute }.to change { model_classes.verification_pending.count }.by(3)
      end
    end
  end
end
