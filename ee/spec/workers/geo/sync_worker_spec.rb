# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::SyncWorker, :geo, feature_category: :geo_replication do
  describe 'sidekiq options' do
    it 'does not set status_expiration at class level' do
      expect(described_class.sidekiq_options['status_expiration']).to be_nil
    end

    it 'sets retry to false' do
      expect(described_class.sidekiq_options['retry']).to be false
    end

    it 'sets dead to false' do
      expect(described_class.sidekiq_options['dead']).to be false
    end
  end

  describe "#perform" do
    let(:sync_service) { instance_double(::Geo::SyncService) }

    before do
      allow(sync_service).to receive(:execute)
      allow(::Geo::SyncService).to receive(:new).with(*job_args).at_least(1).time.and_return(sync_service)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { %w[replicable_name_here 1] }

      it "calls Geo::SyncService" do
        expect(sync_service).to receive(:execute).exactly(worker_exec_times).times

        perform_idempotent_work
      end
    end
  end

  describe 'integration with SidekiqStatus' do
    let(:package_file) { create(:package_file) }
    let(:replicable_name) { 'package_file' }
    let(:model_record_id) { package_file.id }

    context 'when enqueued with explicit status_expiration' do
      it 'creates SidekiqStatus tracking with correct expiration', :clean_gitlab_redis_queues_metadata do
        status_expiration = 100

        jid = described_class.set(status_expiration: status_expiration).perform_async(replicable_name, model_record_id)

        expect(Gitlab::SidekiqStatus.running?(jid)).to be true
      end

      it 'uses 8 hours when set to replicator timeout', :clean_gitlab_redis_queues_metadata do
        status_expiration = Geo::PackageFileReplicator.status_expiration

        jid = described_class.set(status_expiration: status_expiration).perform_async(replicable_name, model_record_id)

        expect(Gitlab::SidekiqStatus.running?(jid)).to be true
      end
    end

    context 'when enqueued without status_expiration' do
      it 'does not create SidekiqStatus tracking', :clean_gitlab_redis_queues_metadata do
        jid = described_class.perform_async(replicable_name, model_record_id)

        expect(Gitlab::SidekiqStatus.running?(jid)).to be false
      end
    end
  end
end
