# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::SelfSigned::AccessDataReader, feature_category: :cloud_connector do
  describe '#read_available_services' do
    subject(:available_services) { described_class.new.read_available_services }

    shared_examples 'a service data reader' do
      it 'parses the service data correctly' do
        expect(available_services).to include({
          duo_chat: be_instance_of(CloudConnector::SelfSigned::AvailableServiceData)
        })
      end

      it 'configures AvailableServiceData objects correctly' do
        expect(available_services[:duo_chat].name).to eq(:duo_chat)
        expect(available_services[:duo_chat].cut_off_date).to eq(Time.zone.parse("2024-10-17T00:00:00Z"))
        expect(available_services[:duo_chat].add_on_names).to match_array(%w[code_suggestions duo_enterprise])
      end
    end

    context 'when use_cloud_connector_available_services_generator is enabled' do
      it_behaves_like 'a service data reader'
    end

    context 'when use_cloud_connector_available_services_generator is disabled' do
      before do
        stub_feature_flags(use_cloud_connector_available_services_generator: false)
      end

      it_behaves_like 'a service data reader'
    end

    it 'both configurations are identical' do
      services_from_generator = described_class.new.send(:access_record_data)
      stub_feature_flags(use_cloud_connector_available_services_generator: false)
      services_from_yaml = described_class.new.send(:access_record_data)

      differences = Hashdiff.diff(services_from_yaml, services_from_generator, strip: true)

      expect(differences).to be_empty, format_diff(differences)
    end

    def format_diff(differences)
      [
        "Differences found between access_data.yml and gitlab_cloud_connector Gem configuration:\n",
        *differences.map do |operation, path, value|
          "#{operation} #{path}: #{value}"
        end
      ].join("\n")
    end
  end
end
