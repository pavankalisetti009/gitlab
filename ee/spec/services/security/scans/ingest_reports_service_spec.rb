# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Scans::IngestReportsService, :clean_gitlab_redis_shared_state, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, user: user) }

  describe '.execute' do
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

    subject(:ingest_security_scans) { service_object.execute }

    before do
      allow(::Security::StoreScansWorker).to receive(:perform_async)
      allow(::Security::ProcessScanEventsWorker).to receive(:perform_async)
    end

    RSpec.shared_examples 'does not start ingestion' do
      it "does not set the polling redis key for mr security widget" do
        expect(::Vulnerabilities::CompareSecurityReportsService).not_to receive(:set_security_mr_widget_to_polling)
        ingest_security_scans
      end

      it 'does not schedule store security scans job' do
        ingest_security_scans

        expect(::Security::StoreScansWorker).not_to have_received(:perform_async)
      end
    end

    RSpec.shared_examples 'starts ingestion' do
      it "set the polling redis key for mr security widget" do
        expect(::Vulnerabilities::CompareSecurityReportsService).to receive(:set_security_mr_widget_to_polling)
          .with(pipeline_id: pipeline.id)

        ingest_security_scans
      end

      it 'schedules store security scans job' do
        ingest_security_scans

        expect(::Security::StoreScansWorker).to have_received(:perform_async).with(pipeline.id)
        expect(::Security::ProcessScanEventsWorker).to have_received(:perform_async).with(pipeline.id)
      end
    end

    context 'when the security scans not completed' do
      let_it_be(:job) { create(:ci_build, :sast, pipeline: pipeline, status: 'running') }

      it_behaves_like 'does not start ingestion'
    end

    context 'when already ingested' do
      let_it_be(:job) { create(:ci_build, :sast, pipeline: pipeline, status: 'success') }
      let_it_be(:mock_cache_key) { SecureRandom.uuid }

      before do
        ::Gitlab::Redis::SharedState.with do |redis|
          !redis.set(mock_cache_key, 'OK', nx: true, ex: described_class::TTL_REPORT_INGESTION)
        end
        allow(pipeline.project).to receive(:can_store_security_reports?).and_return(true)
        allow(service_object).to receive(:scans_cache_key).and_return(mock_cache_key)
      end

      it_behaves_like 'does not start ingestion'
    end

    context 'when the security scans can be stored for the pipeline' do
      let_it_be(:completed_job) { create(:ci_build, :sast, pipeline: pipeline, status: 'success') }
      let_it_be(:mock_cache_key) { SecureRandom.uuid }

      before do
        allow(pipeline.project).to receive(:can_store_security_reports?).and_return(true)
        allow(service_object).to receive(:scans_cache_key).and_return(mock_cache_key)
      end

      context "when all sec jobs completed" do
        it_behaves_like 'starts ingestion'
      end

      context 'when all non-manual security jobs are complete and manual blocking jobs exist' do
        let_it_be(:manual_job) { create(:ci_build, :dast, :manual, :actionable, pipeline: pipeline) }

        it_behaves_like 'starts ingestion'
      end

      context 'when show_child_security_reports_in_mr_widget FF disabled' do
        before do
          stub_feature_flags(show_child_security_reports_in_mr_widget: false)
        end

        it_behaves_like 'starts ingestion'
      end
    end

    context 'when the security scans can not be stored for the pipeline' do
      before do
        allow(pipeline.project).to receive(:can_store_security_reports?).and_return(false)
      end

      let_it_be(:pipeline) { create(:ci_pipeline, user: user) }
      let_it_be(:job) { create(:ci_build, :sast, pipeline: pipeline, status: 'success') }

      it "sets the polling redis key for mr security widget and then sets to ready" do
        expect(::Vulnerabilities::CompareSecurityReportsService).to receive(:set_security_mr_widget_to_polling)
          .with(pipeline_id: pipeline.id)
        expect(::Vulnerabilities::CompareSecurityReportsService).to receive(:set_security_mr_widget_to_ready)
        .with(pipeline_id: pipeline.id)

        ingest_security_scans
      end

      it 'does not schedule store security scans job' do
        ingest_security_scans

        expect(::Security::StoreScansWorker).not_to have_received(:perform_async)
      end
    end

    context 'with parent and child pipelines' do
      let_it_be(:project) { create(:project) }
      let_it_be(:parent_pipeline) { create(:ci_pipeline, project: project, user: user) }
      let_it_be(:child_pipeline) { create(:ci_pipeline, project: project, user: user, child_of: parent_pipeline) }

      context 'when only the child pipeline has security reports' do
        let_it_be(:child_job) { create(:ci_build, :sast, pipeline: child_pipeline, status: 'success') }

        let(:service_object) { described_class.new(child_pipeline) }

        before do
          allow(child_pipeline.project).to receive(:can_store_security_reports?).and_return(true)
        end

        it 'only processes the child pipeline' do
          expect(::Vulnerabilities::CompareSecurityReportsService).to receive(:set_security_mr_widget_to_polling)
            .with(pipeline_id: child_pipeline.id).once
          expect(::Vulnerabilities::CompareSecurityReportsService).not_to receive(:set_security_mr_widget_to_polling)
            .with(pipeline_id: parent_pipeline.id)

          ingest_security_scans

          expect(::Security::StoreScansWorker).to have_received(:perform_async).with(child_pipeline.id).once
          expect(::Security::StoreScansWorker).not_to have_received(:perform_async).with(parent_pipeline.id)
        end

        context 'when feature flag show_child_security_reports_in_mr_widget is disabled' do
          before do
            stub_feature_flags(show_child_security_reports_in_mr_widget: false)
          end

          it 'still processes the child pipeline' do
            ingest_security_scans

            expect(::Security::StoreScansWorker).to have_received(:perform_async)
          end
        end
      end

      context 'when only the parent pipeline has security reports' do
        let_it_be(:parent_job) { create(:ci_build, :sast, pipeline: parent_pipeline, status: 'success') }

        let(:service_object) { described_class.new(parent_pipeline) }

        before do
          allow(parent_pipeline.project).to receive(:can_store_security_reports?).and_return(true)
        end

        it 'only processes the parent pipeline' do
          expect(::Vulnerabilities::CompareSecurityReportsService).to receive(:set_security_mr_widget_to_polling)
            .with(pipeline_id: parent_pipeline.id).once
          expect(::Vulnerabilities::CompareSecurityReportsService).not_to receive(:set_security_mr_widget_to_polling)
            .with(pipeline_id: child_pipeline.id)

          ingest_security_scans

          expect(::Security::StoreScansWorker).to have_received(:perform_async).with(parent_pipeline.id).once
          expect(::Security::StoreScansWorker).not_to have_received(:perform_async).with(child_pipeline.id)
        end

        context 'when feature flag show_child_security_reports_in_mr_widget is disabled' do
          before do
            stub_feature_flags(show_child_security_reports_in_mr_widget: false)
          end

          it 'processes the parent' do
            ingest_security_scans

            expect(::Security::StoreScansWorker).to have_received(:perform_async)
          end
        end
      end

      context 'when both parent and child pipelines have security reports' do
        let_it_be(:parent_job) { create(:ci_build, :sast, pipeline: parent_pipeline, status: 'success') }
        let_it_be(:child_job) { create(:ci_build, :dast, pipeline: child_pipeline, status: 'success') }

        let(:service_object) { described_class.new(child_pipeline) }

        before do
          allow(child_pipeline.project).to receive(:can_store_security_reports?).and_return(true)
        end

        it 'processes both pipelines' do
          expect(::Vulnerabilities::CompareSecurityReportsService).to receive(:set_security_mr_widget_to_polling)
            .with(pipeline_id: parent_pipeline.id).once
          expect(::Vulnerabilities::CompareSecurityReportsService).to receive(:set_security_mr_widget_to_polling)
            .with(pipeline_id: child_pipeline.id).once

          ingest_security_scans

          expect(::Security::StoreScansWorker).to have_received(:perform_async).with(parent_pipeline.id).once
          expect(::Security::StoreScansWorker).to have_received(:perform_async).with(child_pipeline.id).once
        end

        context 'when feature flag show_child_security_reports_in_mr_widget is disabled' do
          before do
            stub_feature_flags(show_child_security_reports_in_mr_widget: false)
          end

          it 'processes the child' do
            ingest_security_scans

            expect(::Security::StoreScansWorker).to have_received(:perform_async).with(child_pipeline.id).once
            expect(::Security::StoreScansWorker).not_to have_received(:perform_async).with(parent_pipeline.id)
          end
        end
      end

      context 'when child pipeline security job is not complete' do
        let_it_be(:parent_job) { create(:ci_build, :sast, pipeline: parent_pipeline, status: 'success') }
        let_it_be(:child_job) { create(:ci_build, :dast, pipeline: child_pipeline, status: 'running') }

        let(:service_object) { described_class.new(parent_pipeline) }

        it 'does not start ingestion until all jobs complete' do
          expect(::Vulnerabilities::CompareSecurityReportsService).not_to receive(:set_security_mr_widget_to_polling)

          ingest_security_scans

          expect(::Security::StoreScansWorker).not_to have_received(:perform_async)
        end
      end
    end
  end
end
