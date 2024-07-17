# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ConcurrencyLimit::ResumeWorker, feature_category: :global_search do
  subject(:worker) { described_class.new }

  let(:worker_with_concurrency_limit) { ElasticCommitIndexerWorker }

  describe '#perform' do
    before do
      allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService).to receive(:resume_processing!)
    end

    context 'when there are no jobs in the queue' do
      before do
        allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService).to receive(:has_jobs_in_queue?)
          .and_return(0)
      end

      it 'does nothing' do
        expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
          .not_to receive(:resume_processing!)

        worker.perform
      end

      it 'reports prometheus metrics' do
        stub_application_setting(elasticsearch_max_code_indexing_concurrency: 30)
        queue_size_gauge_double = instance_double(Prometheus::Client::Gauge)
        expect(Gitlab::Metrics).to receive(:gauge).at_least(:once)
          .with(:sidekiq_concurrency_limit_queue_jobs, anything, {}, :max)
          .and_return(queue_size_gauge_double)

        allow(queue_size_gauge_double).to receive(:set).with({ worker: anything }, 0)
        expect(queue_size_gauge_double).to receive(:set).with({ worker: worker_with_concurrency_limit.name }, 0)

        limit_gauge_double = instance_double(Prometheus::Client::Gauge)
        expect(Gitlab::Metrics).to receive(:gauge).at_least(:once)
                                                  .with(:sidekiq_concurrency_limit_max_concurrent_jobs, anything, {})
                                                  .and_return(limit_gauge_double)

        allow(limit_gauge_double).to receive(:set).with({ worker: anything }, anything)
        expect(limit_gauge_double).to receive(:set).with({ worker: worker_with_concurrency_limit.name }, 30)

        worker.perform
      end
    end

    context 'when there are jobs in the queue' do
      before do
        allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService).to receive(:queue_size)
          .and_return(100)
      end

      it 'resumes processing' do
        stub_application_setting(elasticsearch_max_code_indexing_concurrency: 35)
        expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
         .to receive(:resume_processing!)
         .with(worker_with_concurrency_limit.name, limit: 35)

        worker.perform
      end

      it 'resumes processing if there are other jobs' do
        stub_application_setting(elasticsearch_max_code_indexing_concurrency: 60)
        allow(::Gitlab::SidekiqMiddleware::ConcurrencyLimit::WorkersConcurrency).to receive(:workers)
          .and_return(worker_with_concurrency_limit.name => 15)
        expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
         .to receive(:resume_processing!)
         .with(worker_with_concurrency_limit.name, limit: 45)

        worker.perform
      end

      it 'reports prometheus metrics' do
        stub_application_setting(elasticsearch_max_code_indexing_concurrency: 60)
        allow(::Gitlab::SidekiqMiddleware::ConcurrencyLimit::WorkersConcurrency).to receive(:workers)
          .and_return(worker_with_concurrency_limit.name => 15)

        queue_size_gauge_double = instance_double(Prometheus::Client::Gauge)
        expect(Gitlab::Metrics).to receive(:gauge).at_least(:once)
                                                  .with(:sidekiq_concurrency_limit_queue_jobs, anything, {}, :max)
                                                  .and_return(queue_size_gauge_double)

        allow(queue_size_gauge_double).to receive(:set).with({ worker: anything }, anything)
        expect(queue_size_gauge_double).to receive(:set).with({ worker: worker_with_concurrency_limit.name }, 100)

        limit_gauge_double = instance_double(Prometheus::Client::Gauge)
        expect(Gitlab::Metrics).to receive(:gauge).at_least(:once)
                                                  .with(:sidekiq_concurrency_limit_max_concurrent_jobs, anything, {})
                                                  .and_return(limit_gauge_double)

        allow(limit_gauge_double).to receive(:set).with({ worker: anything }, anything)
        expect(limit_gauge_double).to receive(:set).with({ worker: worker_with_concurrency_limit.name }, 60)

        worker.perform
      end

      context 'when limit is not set' do
        before do
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::WorkersMap).to receive(:limit_for)
          nil_proc = -> { nil }
          allow(::Gitlab::SidekiqMiddleware::ConcurrencyLimit::WorkersMap).to receive(:limit_for)
            .with(worker: worker_with_concurrency_limit)
            .and_return(nil_proc)
        end

        it 'resumes processing using the DEFAULT_LIMIT' do
          expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
            .to receive(:resume_processing!)
              .with(worker_with_concurrency_limit.name, limit: described_class::DEFAULT_LIMIT)
          expect(described_class).to receive(:perform_in)

          worker.perform
        end

        it 'reports limit as DEFAULT_LIMIT' do
          allow(::Gitlab::SidekiqMiddleware::ConcurrencyLimit::WorkersConcurrency).to receive(:workers)
            .and_return(worker_with_concurrency_limit.name => 15)

          queue_size_gauge_double = instance_double(Prometheus::Client::Gauge)
          expect(Gitlab::Metrics).to receive(:gauge).at_least(:once)
                                                    .with(:sidekiq_concurrency_limit_queue_jobs, anything, {}, :max)
                                                    .and_return(queue_size_gauge_double)

          allow(queue_size_gauge_double).to receive(:set).with({ worker: anything }, anything)
          expect(queue_size_gauge_double).to receive(:set).with({ worker: worker_with_concurrency_limit.name }, 100)

          limit_gauge_double = instance_double(Prometheus::Client::Gauge)
          expect(Gitlab::Metrics).to receive(:gauge).at_least(:once)
                                                    .with(:sidekiq_concurrency_limit_max_concurrent_jobs, anything, {})
                                                    .and_return(limit_gauge_double)

          allow(limit_gauge_double).to receive(:set).with({ worker: anything }, anything)
          expect(limit_gauge_double).to receive(:set)
            .with({ worker: worker_with_concurrency_limit.name }, described_class::DEFAULT_LIMIT)

          worker.perform
        end
      end
    end
  end
end
