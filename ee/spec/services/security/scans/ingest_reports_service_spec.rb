# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Scans::IngestReportsService, :clean_gitlab_redis_shared_state, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }

  describe '.execute' do
    let_it_be(:pipeline) { create(:ci_pipeline, user: user) }
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute) { described_class.execute(pipeline) }

    before do
      allow(described_class).to receive(:new).with(pipeline).and_return(mock_service_object)
    end

    it 'delegates the call to an instance of `Security::Scans::IngestReportsService`' do
      execute

      expect(described_class).to have_received(:new).with(pipeline)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let(:service_object) { described_class.new(pipeline) }
    let(:mock_sbom_ingestion_service) { instance_double(::Sbom::ScheduleIngestReportsService, execute: nil) }

    subject(:ingest_security_scans) { service_object.execute }

    before do
      allow(::Security::StoreScansWorker).to receive(:perform_async)
      allow(::Sbom::ScheduleIngestReportsService).to receive(:new)
        .with(pipeline).and_return(mock_sbom_ingestion_service)
    end

    context 'when the security scans not completed' do
      let_it_be(:pipeline) { create(:ci_pipeline, user: user) }
      let_it_be(:job) { create(:ci_build, :sast, pipeline: pipeline, status: 'running') }

      it 'does not schedule store security scans job and to ingests sbom reports' do
        ingest_security_scans

        expect(::Security::StoreScansWorker).not_to have_received(:perform_async)
        expect(::Sbom::ScheduleIngestReportsService).not_to have_received(:new)
      end
    end

    context 'when all non-manual security jobs are complete and manual blocking jobs exist' do
      let_it_be(:pipeline) { create(:ci_pipeline, user: user) }
      let_it_be(:completed_job) { create(:ci_build, :sast, pipeline: pipeline, status: 'success') }
      let_it_be(:manual_job) { create(:ci_build, :dast, :manual, :actionable, pipeline: pipeline) }

      before do
        allow(pipeline).to receive_message_chain(:project,
          :can_store_security_reports?).and_return(true)
      end

      it 'schedules store security scans job' do
        ingest_security_scans

        expect(::Security::StoreScansWorker).to have_received(:perform_async).with(pipeline.id)
      end
    end

    context 'when the security scans can be stored for the pipeline' do
      let_it_be(:pipeline) { create(:ci_pipeline, user: user) }
      let_it_be(:job) { create(:ci_build, :sast, pipeline: pipeline, status: 'success') }
      let_it_be(:mock_cache_key) { SecureRandom.uuid }

      before do
        allow(pipeline).to receive_message_chain(:project,
          :can_store_security_reports?).and_return(true)
        allow(service_object).to receive(:scans_cache_key).and_return(mock_cache_key)
      end

      it 'schedules store security scans job and does not ingest the SBOM reports' do
        ingest_security_scans

        expect(::Security::StoreScansWorker).to have_received(:perform_async).with(pipeline.id)
        expect(::Sbom::ScheduleIngestReportsService).not_to have_received(:new)
      end

      it 'already ingested' do
        ::Gitlab::Redis::SharedState.with do |redis|
          !redis.set(mock_cache_key, 'OK', nx: true, ex: described_class::TTL_REPORT_INGESTION)
        end
        ingest_security_scans

        expect(::Security::StoreScansWorker).not_to have_received(:perform_async)
        expect(::Sbom::ScheduleIngestReportsService).not_to have_received(:new)
      end
    end

    context 'when the security scans can not be stored for the pipeline' do
      before do
        allow(pipeline).to receive_message_chain(:project,
          :can_store_security_reports?).and_return(false)
      end

      let_it_be(:pipeline) { create(:ci_pipeline, user: user) }
      let_it_be(:job) { create(:ci_build, :sast, pipeline: pipeline, status: 'success') }

      it 'does not schedule store security scans job' do
        ingest_security_scans

        expect(::Security::StoreScansWorker).not_to have_received(:perform_async)
      end
    end
  end
end
