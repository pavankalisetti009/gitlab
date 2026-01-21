# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::DisableWorker, feature_category: :global_search do
  let(:worker) { described_class.new }

  it { is_expected.to be_a(ApplicationWorker) }

  describe '#perform' do
    context 'when no active connection exists' do
      it 'returns false', quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/25447' do
        expect(worker.perform).to be false
      end
    end

    context 'when an active connection exists' do
      let_it_be(:connection) do
        create(:ai_active_context_connection, adapter_class: '::ActiveContext::Databases::Elasticsearch::Adapter')
      end

      it 'calls deactivate! on the connection' do
        allow_next_instance_of(Ai::ActiveContext::Connection) do |instance|
          expect(instance).to receive(:deactivate!)
        end

        worker.perform
      end
    end
  end
end
