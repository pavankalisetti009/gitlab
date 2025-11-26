# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::ConnectionService, feature_category: :global_search do
  describe '.connect_to_advanced_search_cluster' do
    let(:application_setting) { build(:application_setting) }

    before do
      allow(ApplicationSetting).to receive(:current).and_return(application_setting)
    end

    context 'when elasticsearch_aws is true' do
      before do
        allow(application_setting).to receive(:elasticsearch_aws).and_return(true)
      end

      it 'creates an opensearch connection with use_advanced_search_config option' do
        described_class.connect_to_advanced_search_cluster

        connection = Ai::ActiveContext::Connection.find_by(name: 'opensearch')

        expect(connection).to be_present
        expect(connection.adapter_class).to eq('ActiveContext::Databases::Opensearch::Adapter')
        expect(connection.use_advanced_search_config_option).to be true
        expect(connection).to be_active
      end
    end

    context 'when elasticsearch_aws is false' do
      before do
        allow(application_setting).to receive(:elasticsearch_aws).and_return(false)
      end

      it 'creates an elasticsearch connection with use_advanced_search_config option' do
        described_class.connect_to_advanced_search_cluster

        connection = Ai::ActiveContext::Connection.find_by(name: 'elasticsearch')

        expect(connection).to be_present
        expect(connection.adapter_class).to eq('ActiveContext::Databases::Elasticsearch::Adapter')
        expect(connection.use_advanced_search_config_option).to be true
        expect(connection).to be_active
      end
    end
  end
end
