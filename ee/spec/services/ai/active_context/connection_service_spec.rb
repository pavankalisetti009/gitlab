# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::ConnectionService, feature_category: :global_search do
  describe '.connect_to_advanced_search_cluster' do
    let(:elastic_helper) { instance_double(Gitlab::Elastic::Helper) }

    before do
      allow(Gitlab::Elastic::Helper).to receive(:default).and_return(elastic_helper)
    end

    context 'when distribution is opensearch' do
      before do
        allow(elastic_helper).to receive(:matching_distribution?).with(:opensearch).and_return(true)
        allow(elastic_helper).to receive(:matching_distribution?).with(:elasticsearch).and_return(false)
      end

      it 'creates an opensearch connection with use_advanced_search_config option' do
        described_class.connect_to_advanced_search_cluster

        connection = Ai::ActiveContext::Connection.find_by(name: 'opensearch')

        expect(connection).to be_present
        expect(connection.adapter_class).to eq('ActiveContext::Databases::Opensearch::Adapter')
        expect(connection.use_advanced_search_config_option).to be true
        expect(connection).to be_active
      end

      context 'when an active connection already exists' do
        let!(:existing_connection) do
          create(:ai_active_context_connection, active: true, name: 'existing')
        end

        it 'deactivates the existing connection' do
          described_class.connect_to_advanced_search_cluster

          expect(existing_connection.reload).not_to be_active
        end

        it 'activates the new connection' do
          described_class.connect_to_advanced_search_cluster

          new_connection = Ai::ActiveContext::Connection.find_by(name: 'opensearch')
          expect(new_connection).to be_active
        end
      end
    end

    context 'when distribution is elasticsearch' do
      before do
        allow(elastic_helper).to receive(:matching_distribution?).with(:opensearch).and_return(false)
        allow(elastic_helper).to receive(:matching_distribution?).with(:elasticsearch).and_return(true)
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

    context 'when distribution is neither opensearch nor elasticsearch' do
      before do
        allow(elastic_helper).to receive(:matching_distribution?).with(:opensearch).and_return(false)
        allow(elastic_helper).to receive(:matching_distribution?).with(:elasticsearch).and_return(false)
      end

      it 'raises a ConnectionError' do
        expect do
          described_class.connect_to_advanced_search_cluster
        end.to raise_error(described_class::ConnectionError, 'Connection invalid')
      end

      it 'does not create a connection' do
        expect do
          described_class.connect_to_advanced_search_cluster
        end.to raise_error(described_class::ConnectionError)
          .and not_change { Ai::ActiveContext::Connection.count }
      end
    end
  end
end
