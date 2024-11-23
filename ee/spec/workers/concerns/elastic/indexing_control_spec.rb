# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::IndexingControl, feature_category: :global_search do
  let!(:project) { create(:project, :repository) }
  let(:worker_args) { [project.id] }
  let(:worker_context) do
    { 'correlation_id' => 'context_correlation_id', 'meta.sidekiq_destination_shard_redis' => 'main' }
  end

  context 'with stub_const' do
    let_it_be(:worker) do
      Class.new do
        def perform(project_id)
          project = Project.find(project_id)

          Gitlab::Elastic::Indexer.new(project).run
        end

        def self.name
          'TestIndexingControlWorker'
        end

        include ApplicationWorker
        prepend Elastic::IndexingControl
      end.new
    end

    before do
      stub_const("Elastic::IndexingControl::WORKERS", [worker.class])
    end

    describe '.non_cached_pause_indexing?' do
      it 'calls current_without_cache' do
        expect(described_class.non_cached_pause_indexing?).to be(false)
      end
    end

    describe '.resume_processing!' do
      before do
        allow(described_class).to receive(:non_cached_pause_indexing?).and_return(false)
      end

      it 'triggers job processing if there are jobs' do
        expect(Elastic::IndexingControlService).to receive(:has_jobs_in_waiting_queue?).with(worker.class)
          .and_return(true)
        expect(Elastic::IndexingControlService).to receive(:resume_processing!).with(worker.class)

        described_class.resume_processing!
      end

      it 'does nothing if no jobs available' do
        expect(Elastic::IndexingControlService).to receive(:has_jobs_in_waiting_queue?).with(worker.class)
          .and_return(false)
        expect(Elastic::IndexingControlService).not_to receive(:resume_processing!)

        described_class.resume_processing!
      end
    end

    context 'with elasticsearch indexing paused' do
      before do
        allow(described_class).to receive(:non_cached_pause_indexing?).and_return(true)
      end

      it 'adds jobs to the waiting queue' do
        expect_any_instance_of(Gitlab::Elastic::Indexer).not_to receive(:run)
        expect(Elastic::IndexingControlService).to receive(:add_to_waiting_queue!)
          .with(worker.class, worker_args, hash_including(worker_context))

        Gitlab::ApplicationContext.with_raw_context(worker_context) do
          worker.perform(*worker_args)
        end
      end

      it 'ignores changes from a different worker' do
        stub_const("Elastic::IndexingControl::WORKERS", [])

        expect_any_instance_of(Gitlab::Elastic::Indexer).to receive(:run)
        expect(Elastic::IndexingControlService).not_to receive(:add_to_waiting_queue!)

        worker.perform(*worker_args)
      end
    end

    context 'with elasticsearch indexing unpaused' do
      before do
        allow(described_class).to receive(:non_cached_pause_indexing?).and_return(false)
      end

      it 'performs the job' do
        expect_next_instance_of(Gitlab::Elastic::Indexer) do |indexer|
          expect(indexer).to receive(:run)
        end
        expect(Elastic::IndexingControlService).not_to receive(:track!)

        worker.perform(*worker_args)
      end
    end
  end
end
