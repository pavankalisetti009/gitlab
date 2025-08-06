# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::PartnerTokenVerificationWorker, feature_category: :secret_detection do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:finding) { create(:vulnerabilities_finding, project: project) }

  subject(:worker) { described_class.new }

  describe '#perform' do
    let(:service) { instance_double(Security::SecretDetection::TokenVerificationRequestService) }
    let(:service_response) { ServiceResponse.success(payload: { finding_id: finding.id, request_id: 'abc-123' }) }

    before do
      allow(Security::SecretDetection::TokenVerificationRequestService)
        .to receive(:new).with(user, finding).and_return(service)
      allow(service).to receive(:execute).and_return(service_response)
    end

    context 'when finding and user exist' do
      it 'calls the service with correct parameters' do
        worker.perform(finding.id, user.id)

        expect(Security::SecretDetection::TokenVerificationRequestService)
          .to have_received(:new).with(user, finding)
        expect(service).to have_received(:execute)
      end

      context 'when service returns success' do
        it 'logs success metadata' do
          expect(worker).to receive(:log_extra_metadata_on_done).with(:status, 'success')
          expect(worker).to receive(:log_extra_metadata_on_done).with(:finding_id, finding.id)
          expect(worker).to receive(:log_extra_metadata_on_done).with(:request_id, 'abc-123')

          worker.perform(finding.id, user.id)
        end
      end

      context 'when service returns error' do
        let(:service_response) do
          ServiceResponse.error(
            message: 'Configuration error',
            payload: { error_type: :configuration_error }
          )
        end

        it 'logs error metadata and does not retry' do
          expect(worker).to receive(:log_extra_metadata_on_done).with(:status, 'error')
          expect(worker).to receive(:log_extra_metadata_on_done).with(:error_message, 'Configuration error')
          expect(worker).to receive(:log_extra_metadata_on_done).with(:error_type, :configuration_error)
          expect(worker).to receive(:log_extra_metadata_on_done).with(:retry_decision, 'not_retryable')

          worker.perform(finding.id, user.id)
        end
      end

      context 'when service returns retryable network error' do
        let(:service_response) do
          ServiceResponse.error(
            message: 'Unexpected error during SDRS request: Connection timeout',
            payload: { error_type: Net::OpenTimeout }
          )
        end

        it 'raises exception to trigger retry' do
          expect { worker.perform(finding.id, user.id) }
            .to raise_error(StandardError, 'Unexpected error during SDRS request: Connection timeout')
        end
      end

      context 'when service returns non-retryable error' do
        let(:service_response) do
          ServiceResponse.error(
            message: 'Unauthorized',
            payload: { error_type: :unauthorized }
          )
        end

        it 'does not raise exception' do
          expect { worker.perform(finding.id, user.id) }.not_to raise_error
        end
      end
    end

    context 'when finding does not exist' do
      it 'logs and returns early' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: 'Finding not found',
          worker_class: described_class.name,
          finding_id: non_existing_record_id,
          user_id: user.id
        )
        expect(worker).to receive(:log_extra_metadata_on_done).with(:status, 'skipped')
        expect(worker).to receive(:log_extra_metadata_on_done).with(:reason, 'Finding not found')

        worker.perform(non_existing_record_id, user.id)

        expect(service).not_to have_received(:execute)
      end
    end

    context 'when user does not exist' do
      it 'logs and returns early' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: 'User not found',
          worker_class: described_class.name,
          finding_id: finding.id,
          user_id: non_existing_record_id
        )
        expect(worker).to receive(:log_extra_metadata_on_done).with(:status, 'skipped')
        expect(worker).to receive(:log_extra_metadata_on_done).with(:reason, 'User not found')

        worker.perform(finding.id, non_existing_record_id)

        expect(service).not_to have_received(:execute)
      end
    end
  end

  describe 'sidekiq_retry_in_block' do
    it 'returns exponential backoff for retryable exceptions within retry limit' do
      retryable_exception = Net::OpenTimeout.new

      expect(described_class.sidekiq_retry_in_block.call(0, retryable_exception)).to eq(1)
      expect(described_class.sidekiq_retry_in_block.call(1, retryable_exception)).to eq(4)
      expect(described_class.sidekiq_retry_in_block.call(2, retryable_exception)).to eq(16)
    end

    it 'returns false after 3 retries or for non-retryable exceptions' do
      retryable_exception = Net::OpenTimeout.new
      non_retryable_exception = StandardError.new

      expect(described_class.sidekiq_retry_in_block.call(3, retryable_exception)).to be(false)
      expect(described_class.sidekiq_retry_in_block.call(0, non_retryable_exception)).to be(false)
    end
  end

  describe 'retryable exceptions' do
    it 'includes expected network exceptions' do
      expect(described_class::RETRYABLE_EXCEPTIONS).to include(
        Net::OpenTimeout,
        EOFError,
        SocketError,
        OpenSSL::SSL::SSLError,
        Errno::ECONNRESET,
        Errno::ECONNREFUSED
      )
    end
  end
end
