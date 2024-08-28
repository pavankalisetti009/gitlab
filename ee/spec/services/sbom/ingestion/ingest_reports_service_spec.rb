# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::IngestReportsService, feature_category: :dependency_management do
  let_it_be(:pipeline) { build_stubbed(:ci_pipeline) }
  let_it_be(:reports) { create_list(:ci_reports_sbom_report, 4) }

  let(:sequencer) { ::Ingestion::Sequencer.new }
  let(:wrapper) { instance_double('Gitlab::Ci::Reports::Sbom::Reports') }
  let(:vulnerability_info) { instance_double('Sbom::Ingestion::Vulnerabilities') }

  subject(:execute) { described_class.execute(pipeline) }

  before do
    allow(wrapper).to receive(:reports).and_return(reports)
    allow(pipeline).to receive(:sbom_reports).with(self_and_project_descendants: true).and_return(wrapper)
    allow(::Sbom::Ingestion::Vulnerabilities).to receive(:new).and_return(vulnerability_info)
  end

  describe '#execute' do
    using RSpec::Parameterized::TableSyntax

    where(:feature_flag, :feature_flag_stub, :expected_vulnerability_info) do
      :deprecate_vulnerability_occurrence_pipelines | false | ref(:vulnerability_info)
      :deprecate_vulnerability_occurrence_pipelines | true | {}
    end

    with_them do
      before do
        stub_feature_flags(feature_flag => feature_flag_stub)
        allow(::Sbom::Ingestion::DeleteNotPresentOccurrencesService).to receive(:execute)
        allow(::Sbom::Ingestion::IngestReportService).to receive(:execute)
                                                           .and_wrap_original do |_, _, report|
          report.components.map { sequencer.next }
        end
      end

      it 'executes IngestReportService for each report' do
        reports.each do |report|
          expect(::Sbom::Ingestion::IngestReportService).to receive(:execute).with(pipeline, report,
            expected_vulnerability_info)
        end

        execute

        expect(::Sbom::Ingestion::DeleteNotPresentOccurrencesService).to have_received(:execute)
                                                                           .with(pipeline, sequencer.range)
      end

      context 'when lease is taken' do
        include ExclusiveLeaseHelpers

        let(:lease_key) { Sbom::Ingestion.project_lease_key(pipeline.project.id) }

        before do
          # Speed up retries to avoid long-running tests
          stub_const("#{described_class}::LEASE_TRY_AFTER", 0.01)
          stub_exclusive_lease_taken(lease_key)
        end

        it 'does not permit parallel execution on the same project' do
          expect { execute }.to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)

          expect(::Sbom::Ingestion::IngestReportService).not_to have_received(:execute)
        end
      end

      context 'when feature flag store_sbom_report_ingestion_errors is enabled' do
        before do
          stub_feature_flags(store_sbom_report_ingestion_errors: true)
        end

        it 'does not set SBOM ingestion errors when report is valid' do
          allow(pipeline).to receive(:set_sbom_report_ingestion_errors)

          execute

          expect(pipeline).not_to have_received(:set_sbom_report_ingestion_errors)
        end
      end

      context 'when feature flag dependency_scanning_using_sbom_reports is enabled' do
        it 'publishes the pipeline id to the event store' do
          expect { execute }.to publish_event(::Sbom::SbomIngestedEvent).with({ pipeline_id: pipeline.id })
        end
      end

      context 'when feature flag dependency_scanning_using_sbom_reports is disabled' do
        before do
          stub_feature_flags(dependency_scanning_using_sbom_reports: false)
        end

        it 'does not publish anything to the event store' do
          expect(Gitlab::EventStore).not_to receive(:publish)
        end
      end

      context 'when a report is invalid' do
        let_it_be(:sbom_ingestion_error) { 'Unsupported CycloneDX version' }
        let_it_be(:invalid_report) { create(:ci_reports_sbom_report, :invalid, error: sbom_ingestion_error) }
        let_it_be(:valid_reports) { create_list(:ci_reports_sbom_report, 4) }
        let_it_be(:reports) { [invalid_report] + valid_reports }

        it 'does not process the invalid report' do
          expect(::Sbom::Ingestion::IngestReportService).not_to receive(:execute).with(pipeline,
            invalid_report,
            vulnerability_info)

          valid_reports.each do |report|
            expect(::Sbom::Ingestion::IngestReportService).to receive(:execute).with(pipeline, report,
              expected_vulnerability_info)
          end

          execute

          expect(::Sbom::Ingestion::DeleteNotPresentOccurrencesService).to have_received(:execute)
                                                                             .with(pipeline, sequencer.range)
        end

        context 'when feature flag store_sbom_report_ingestion_errors is enabled' do
          before do
            stub_feature_flags(store_sbom_report_ingestion_errors: true)
          end

          it 'sets the ingestion errors' do
            execute

            expect(pipeline.has_sbom_report_ingestion_errors?).to be_truthy
            expect(pipeline.sbom_report_ingestion_errors).to eq([[sbom_ingestion_error]])
          end
        end

        context 'when feature flag store_sbom_report_ingestion_errors is disabled' do
          before do
            stub_feature_flags(store_sbom_report_ingestion_errors: false)
            allow(pipeline).to receive(:set_sbom_report_ingestion_errors)
          end

          it 'does not set the ingestion errors' do
            execute

            expect(pipeline).not_to have_received(:set_sbom_report_ingestion_errors)
          end
        end
      end

      context 'when a report source is container_scanning_for_registry' do
        let_it_be(:sbom_ingestion_error) { 'Unsupported CycloneDX version' }
        let_it_be(:registry_sources) { create(:ci_reports_sbom_source, :container_scanning_for_registry) }
        let_it_be(:reports) { [create(:ci_reports_sbom_report, source: registry_sources)] }

        it 'ingest the report but does not delete the existing occurrences' do
          expect(::Sbom::Ingestion::IngestReportService).to receive(:execute).with(pipeline,
            reports.first,
            expected_vulnerability_info)

          execute

          expect(::Sbom::Ingestion::DeleteNotPresentOccurrencesService).not_to have_received(:execute)
                                                                                 .with(pipeline, sequencer.range)
        end
      end

      describe 'setting the latest ingested SBOM pipeline ID' do
        let(:project) { pipeline.project }

        before do
          allow(project).to receive(:set_latest_ingested_sbom_pipeline_id)
        end

        it 'sets the latest ingested SBOM pipeline ID' do
          execute

          expect(project).to have_received(:set_latest_ingested_sbom_pipeline_id).with(pipeline.id)
        end
      end
    end
  end
end
