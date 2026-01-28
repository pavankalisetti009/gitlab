# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::Secrets::CreateServiceHelpers,
  feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:current_user) { user }

  let(:service_instance) do
    Class.new do
      include SecretsManagement::Secrets::CreateServiceHelpers

      attr_reader :secrets_manager, :current_user

      def initialize(secrets_manager, current_user)
        @secrets_manager = secrets_manager
        @current_user = current_user
      end
    end.new(secrets_manager, current_user)
  end

  let(:count_service) { instance_double(SecretsManagement::ProjectSecretsCountService) }

  before do
    allow(service_instance).to receive(:current_secret_count) { count_service.execute }
    allow(count_service).to receive(:execute).and_return(0)
    allow(secrets_manager).to receive(:active?).and_return(true) if secrets_manager
  end

  describe '#secrets_limit_exceeded?' do
    subject(:limit_exceeded?) { service_instance.send(:secrets_limit_exceeded?) }

    context 'when secrets_manager is nil' do
      let(:secrets_manager) { nil }

      it 'returns false' do
        expect(limit_exceeded?).to be(false)
      end
    end

    context 'when secrets_limit is 0 (unlimited)' do
      before do
        allow(secrets_manager).to receive(:secrets_limit).and_return(0)
      end

      it 'returns false' do
        expect(limit_exceeded?).to be(false)
      end

      it 'does not call current_secret_count' do
        expect(count_service).not_to receive(:execute)

        limit_exceeded?
      end
    end

    context 'when secrets_count is below the limit' do
      before do
        allow(secrets_manager).to receive(:secrets_limit).and_return(100)
        allow(count_service).to receive(:execute).and_return(99)
      end

      it 'returns false' do
        expect(limit_exceeded?).to be(false)
      end
    end

    context 'when secrets_count meets the limit' do
      before do
        allow(secrets_manager).to receive(:secrets_limit).and_return(100)
        allow(count_service).to receive(:execute).and_return(100)
      end

      it 'returns true' do
        expect(limit_exceeded?).to be(true)
      end
    end

    context 'when secrets_count exceeds the limit' do
      before do
        allow(secrets_manager).to receive(:secrets_limit).and_return(100)
        allow(count_service).to receive(:execute).and_return(101)
      end

      it 'returns true' do
        expect(limit_exceeded?).to be(true)
      end
    end

    context 'when current_secret_count raises an error' do
      let(:error) { StandardError.new('boom') }

      before do
        allow(secrets_manager).to receive(:secrets_limit).and_return(100)
        allow(count_service).to receive(:execute).and_raise(error)
      end

      it 'raises the error so the caller receives the actual failure' do
        expect { limit_exceeded? }.to raise_error(StandardError, 'boom')
      end
    end
  end

  describe '#secrets_limit_exceeded_response' do
    subject(:response) { service_instance.send(:secrets_limit_exceeded_response) }

    context 'when secrets_manager is ProjectSecretsManager' do
      let(:secrets_manager) { create(:project_secrets_manager, project: project) }

      before do
        allow(secrets_manager).to receive(:secrets_limit).and_return(123)
      end

      it 'returns an error ServiceResponse with the expected reason' do
        expect(response).to be_error
        expect(response.reason).to eq(:secrets_limit_exceeded)
      end

      it 'includes the limit and scope in the message' do
        expect(response.message).to include('Maximum number of secrets (123)')
        expect(response.message).to include('for this project')
      end
    end

    context 'when secrets_manager is GroupSecretsManager' do
      let(:secrets_manager) { create(:group_secrets_manager, group: group) }

      before do
        allow(service_instance).to receive(:current_secret_count) { count_service.execute }
        allow(secrets_manager).to receive(:secrets_limit).and_return(456)
      end

      it 'returns an error ServiceResponse with the expected reason' do
        expect(response).to be_error
        expect(response.reason).to eq(:secrets_limit_exceeded)
      end

      it 'includes the limit and scope in the message' do
        expect(response.message).to include('Maximum number of secrets (456)')
        expect(response.message).to include('for this group')
      end
    end
  end
end
