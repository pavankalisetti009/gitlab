# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Connection, feature_category: :global_search do
  it_behaves_like 'it has loose foreign keys' do
    let(:factory_name) { :ai_active_context_connection }
  end

  describe 'associations' do
    it { is_expected.to have_many(:migrations).class_name('Ai::ActiveContext::Migration') }
  end

  describe 'validations' do
    subject { build(:ai_active_context_connection) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:adapter_class) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:adapter_class).is_at_most(255) }
    it { is_expected.to validate_length_of(:prefix).is_at_most(255) }

    describe 'options validation' do
      let(:connection) { build(:ai_active_context_connection) }

      it 'validates options is valid hash' do
        connection.options = { key: 'value' }
        expect(connection).to be_valid

        connection.options = 'not a hash'
        expect(connection).not_to be_valid
        expect(connection.errors[:options]).to include('must be a hash')

        connection.options = { key: :value }
        expect(connection).to be_valid
      end
    end
  end

  describe 'encryption' do
    it 'encrypts options' do
      connection = create(:ai_active_context_connection)
      saved_connection = described_class.find(connection.id)

      # The encrypted value should be different from the original
      expect(saved_connection.options['token']).to eq(connection.options['token'])
      expect(saved_connection.attributes['options']).not_to include(connection.options['token'])
    end
  end

  describe '.active' do
    let!(:active_connection) { create(:ai_active_context_connection) }
    let!(:inactive_connection) { create(:ai_active_context_connection, :inactive) }

    it 'returns only active connection' do
      expect(described_class.active).to eq(active_connection)
    end
  end

  describe '#use_advanced_search_config_option' do
    context 'when use_advanced_search_config is true' do
      let(:connection) do
        build(:ai_active_context_connection, options: { use_advanced_search_config: true })
      end

      it 'returns true' do
        expect(connection.use_advanced_search_config_option).to be true
      end
    end

    context 'when use_advanced_search_config is false' do
      let(:connection) do
        build(:ai_active_context_connection, options: { use_advanced_search_config: false })
      end

      it 'returns false' do
        expect(connection.use_advanced_search_config_option).to be false
      end
    end

    context 'when use_advanced_search_config is not present' do
      let(:connection) do
        build(:ai_active_context_connection, options: { url: 'http://custom:9200' })
      end

      it 'returns nil' do
        expect(connection.use_advanced_search_config_option).to be_nil
      end
    end
  end

  describe '#options' do
    context 'when use_advanced_search_config is true for elasticsearch adapter' do
      let(:connection) do
        build(:ai_active_context_connection,
          adapter_class: 'ActiveContext::Databases::Elasticsearch::Adapter',
          options: { use_advanced_search_config: true })
      end

      let(:gitlab_elasticsearch_config) do
        {
          url: [{ scheme: 'http', host: '127.0.0.1', port: 9200, path: '' }],
          aws: false,
          client_request_timeout: 30,
          retry_on_failure: 3
        }
      end

      before do
        allow(::Gitlab::CurrentSettings).to receive(:elasticsearch_config).and_return(gitlab_elasticsearch_config)
      end

      it 'returns GitLab elasticsearch config directly' do
        expect(connection.options).to eq(gitlab_elasticsearch_config)
      end
    end

    context 'when use_advanced_search_config is false' do
      let(:custom_options) { { url: 'http://custom:9200' } }
      let(:connection) do
        build(:ai_active_context_connection,
          adapter_class: 'ActiveContext::Databases::Elasticsearch::Adapter',
          options: custom_options.merge(use_advanced_search_config: false))
      end

      it 'returns the stored options' do
        expect(connection.options).to eq(custom_options.stringify_keys.merge('use_advanced_search_config' => false))
      end
    end

    context 'when adapter is not elasticsearch' do
      let(:custom_options) { { token: 'secret', use_advanced_search_config: true } }
      let(:connection) do
        build(:ai_active_context_connection,
          adapter_class: 'SomeOtherAdapter',
          options: custom_options)
      end

      it 'returns the stored options' do
        expect(connection.options).to eq(custom_options.stringify_keys)
      end
    end

    context 'when use_advanced_search_config is not present' do
      let(:custom_options) { { url: 'http://custom:9200' } }
      let(:connection) do
        build(:ai_active_context_connection,
          adapter_class: 'ActiveContext::Databases::Elasticsearch::Adapter',
          options: custom_options)
      end

      it 'returns the stored options' do
        expect(connection.options).to eq(custom_options.stringify_keys)
      end
    end
  end

  describe '#activate!' do
    let!(:active_connection) { create(:ai_active_context_connection) }
    let!(:inactive_connection) { create(:ai_active_context_connection, :inactive) }

    context 'when the connection is already active' do
      it 'does not make any changes' do
        expect { active_connection.activate! }.not_to change { Ai::ActiveContext::Connection.active }
      end
    end

    context 'when the connection is inactive' do
      it 'activates the connection and deactivates the previously active connection' do
        expect do
          inactive_connection.activate!
        end.to change { Ai::ActiveContext::Connection.active }.from(active_connection).to(inactive_connection)

        expect(active_connection.reload).not_to be_active
        expect(inactive_connection.reload).to be_active
      end
    end

    context 'when an error occurs during activation' do
      before do
        allow(inactive_connection).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'rolls back the transaction and does not change the active connection' do
        expect do
          expect { inactive_connection.activate! }.to raise_error(ActiveRecord::RecordInvalid)
        end.not_to change { Ai::ActiveContext::Connection.active }

        expect(active_connection.reload).to be_active
        expect(inactive_connection.reload).not_to be_active
      end
    end
  end

  describe '#deactivate!' do
    context 'when the connection is already inactive' do
      let!(:connection) { create(:ai_active_context_connection, :inactive) }

      it 'does not make any changes' do
        expect { connection.deactivate! }.not_to change { connection.reload.active }
      end
    end

    context 'when the connection is active' do
      let!(:connection) { create(:ai_active_context_connection) }

      it 'deactivates the connection' do
        expect { connection.deactivate! }.to change { connection.reload.active }.from(true).to(false)
      end
    end
  end
end
