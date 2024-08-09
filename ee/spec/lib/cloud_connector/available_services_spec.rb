# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::AvailableServices, feature_category: :cloud_connector do
  context 'when .com', :saas do
    it 'returns SelfSigned::AccessDataReader' do
      expect(described_class.access_data_reader)
        .to be_a_kind_of(CloudConnector::SelfSigned::AccessDataReader)
    end
  end

  context 'when CLOUD_CONNECTOR_SELF_SIGN_TOKENS is set' do
    before do
      stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', '1')
      # Need to disable this so as not to mix up this use case with the
      # Custom Models experiment.
      stub_feature_flags(ai_custom_model: false)
    end

    it 'returns SelfSigned::SelfManaged outside of development' do
      expect(described_class.access_data_reader)
        .to be_a_kind_of(CloudConnector::SelfManaged::AccessDataReader)
    end

    it 'returns SelfSigned::AccessDataReader in development' do
      stub_rails_env('development')

      expect(described_class.access_data_reader)
        .to be_a_kind_of(CloudConnector::SelfSigned::AccessDataReader)
    end
  end

  context 'when the AI gateway service is self-hosted' do
    it 'returns SelfManaged::AccessDataReader if CLOUD_CONNECTOR_SELF_SIGN_TOKENS is disabled' do
      expect(described_class.access_data_reader)
        .to be_a_kind_of(CloudConnector::SelfManaged::AccessDataReader)
    end

    context 'when CLOUD_CONNECTOR_SELF_SIGN_TOKENS is enabled' do
      before do
        stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', '1')
      end

      it 'returns SelfSigned::AccessDataReader' do
        expect(described_class.access_data_reader)
          .to be_a_kind_of(CloudConnector::SelfSigned::AccessDataReader)
      end

      context 'when ai_custom_model is disabled' do
        before do
          stub_feature_flags(ai_custom_model: false)
        end

        it 'returns SelfManaged::AccessDataReader' do
          expect(described_class.access_data_reader)
            .to be_a_kind_of(CloudConnector::SelfManaged::AccessDataReader)
        end
      end
    end
  end

  context 'when self_managed' do
    it 'returns SelfManaged::AccessDataReader' do
      expect(described_class.access_data_reader)
        .to be_a_kind_of(CloudConnector::SelfManaged::AccessDataReader)
    end
  end

  describe '.find_by_name' do
    before do
      allow(described_class).to receive(:access_data_reader)
        .and_return(::CloudConnector::SelfManaged::AccessDataReader.new)
    end

    it 'reads available service' do
      available_services = { duo_chat: CloudConnector::BaseAvailableServiceData.new(:duo_chat, nil, nil) }
      expect(described_class.access_data_reader).to receive(:read_available_services).and_return(available_services)

      service = described_class.find_by_name(:duo_chat)

      expect(service.name).to eq(:duo_chat)
    end

    context 'when available_services is empty' do
      it 'returns null service data' do
        expect(described_class.access_data_reader).to receive(:read_available_services).and_return([])

        service = described_class.find_by_name(:duo_chat)

        expect(service.name).to eq(:missing_service)
        expect(service).to be_instance_of(CloudConnector::MissingServiceData)
      end
    end

    context 'when available_services does not contain the requested name' do
      it 'returns null service data' do
        available_services = { duo_chat: CloudConnector::BaseAvailableServiceData.new(:duo_chat, nil, nil) }
        expect(described_class.access_data_reader).to receive(:read_available_services).and_return(available_services)

        service = described_class.find_by_name(:service_name_that_is_not_synced_or_typo)

        expect(service.name).to eq(:missing_service)
        expect(service).to be_instance_of(CloudConnector::MissingServiceData)
      end
    end
  end
end
