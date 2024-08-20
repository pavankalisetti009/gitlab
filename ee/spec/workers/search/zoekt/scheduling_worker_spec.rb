# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::SchedulingWorker, feature_category: :global_search do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always

  it 'is not a pause_control worker' do
    expect(described_class.get_pause_control).not_to eq(:zoekt)
  end

  describe '#perform' do
    context 'when no arguments are provided' do
      subject(:worker) { described_class.new }

      context 'when feature flag zoekt_scheduling_worker is disabled' do
        it_behaves_like 'an idempotent worker' do
          before do
            stub_feature_flags(zoekt_scheduling_worker: false)
          end

          it 'does not call the service' do
            expect(worker.perform).to be false
            expect(Search::Zoekt::SchedulingWorker).not_to receive(:new)
          end
        end
      end

      it_behaves_like 'an idempotent worker' do
        it 'calls the worker with each supported tasks' do
          Search::Zoekt::SchedulingService::TASKS.each do |t|
            expect(described_class).to receive(:perform_async).with(t)
          end

          worker.perform
        end
      end
    end

    context 'when task is provided' do
      subject(:worker) { described_class.new }

      let(:task) { :node_assignment }

      it_behaves_like 'an idempotent worker' do
        it 'calls the service with the task' do
          expect(Search::Zoekt::SchedulingService).to receive(:execute).with(task)

          worker.perform(task)
        end
      end
    end
  end
end
