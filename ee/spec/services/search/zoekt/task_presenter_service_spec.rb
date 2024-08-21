# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::TaskPresenterService, feature_category: :global_search do
  let_it_be(:node) { create(:zoekt_node) }
  let_it_be(:task) { create(:zoekt_task, node: node) }

  let(:service) { described_class.new(node) }

  subject(:execute_task) { service.execute }

  describe '.execute' do
    it 'passes arguments to new and calls execute' do
      expect(described_class).to receive(:new).with(node).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(node)
    end
  end

  describe '#execute' do
    context 'when application setting zoekt_indexing_paused is true' do
      before do
        stub_ee_application_setting(zoekt_indexing_paused: true)
      end

      it 'does nothing' do
        expect(::Search::Zoekt::TaskSerializerService).not_to receive(:execute)

        expect(execute_task).to be_empty
      end
    end

    context 'when application setting zoekt_indexing_paused is false' do
      before do
        stub_ee_application_setting(zoekt_indexing_paused: false)
      end

      it 'returns serialized tasks' do
        expect(execute_task).to contain_exactly(::Search::Zoekt::TaskSerializerService.execute(task))
      end
    end
  end

  describe '.concurrency_limit' do
    subject(:concurrency_limit) { service.concurrency_limit }

    context 'when node does not have task_count/concurrency set' do
      let(:node) { build(:zoekt_node) }

      it 'returns the default limit' do
        expect(concurrency_limit).to eq(described_class::DEFAULT_LIMIT)
      end
    end

    context 'when node has task_count/concurrency set' do
      using RSpec::Parameterized::TableSyntax

      where(:concurrency, :concurrency_override, :result) do
        0   | nil | described_class::DEFAULT_LIMIT
        10  | 0   | 20
        1   | nil | 1
        10  | 20  | 20
        200 | nil | described_class::MAX_LIMIT
      end

      with_them do
        let(:node) do
          build(:zoekt_node,
            metadata: { 'concurrency' => concurrency,
                        'concurrency_override' => concurrency_override })
        end

        it 'returns correct value' do
          expect(concurrency_limit).to eq(result)
        end
      end
    end
  end
end
