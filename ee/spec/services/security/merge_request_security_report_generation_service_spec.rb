# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::MergeRequestSecurityReportGenerationService, :use_clean_rails_memory_store_caching, :sidekiq_inline, feature_category: :vulnerability_management do
  include ReactiveCachingHelpers

  describe '#execute' do
    let_it_be(:merge_request) { create(:merge_request) }

    let(:params) { { report_type: } }
    let(:report_generation_service) { described_class.new(merge_request, params) }

    subject(:report) { report_generation_service.execute }

    def stub_report(data)
      allow_next_instance_of(Vulnerabilities::CompareSecurityReportsService, merge_request.project, nil,
        params) do |instance|
        expect(instance).to receive(:latest?)
          .with(
            merge_request.comparison_base_pipeline(Vulnerabilities::CompareSecurityReportsService),
            merge_request.diff_head_pipeline,
            data
          )
          .and_return(true)
      end
      stub_reactive_cache(report_generation_service, data, params.stringify_keys)
    end

    context 'when the given report type is invalid' do
      let(:report_type) { 'foo' }

      it 'raises InvalidReportTypeError' do
        expect { report }.to raise_error(described_class::InvalidReportTypeError)
      end
    end

    context 'with severity override' do
      let_it_be(:project) { create(:project) }
      let_it_be(:new_uuid) { SecureRandom.uuid }
      let_it_be(:overridden_finding) do
        create(:vulnerabilities_finding,
          :with_severity_override,
          project: project,
          severity: :high,
          uuid: new_uuid,
          name: 'Test vulnerability with override'
        )
      end

      let_it_be(:severity_override) { overridden_finding.vulnerability.severity_overrides.last }

      let_it_be(:severity_override_data) do
        options = {
          only: [:vulnerability_id, :created_at, :original_severity, :new_severity],
          methods: [:author_data]
        }
        severity_override.as_json(options)
      end

      let(:report_type) { 'sast' }
      let(:mock_report) do
        {
          status: :parsed,
          data: {
            'base_report_created_at' => nil,
            'base_report_out_of_date' => false,
            'head_report_created_at' => '2023-01-18T11:30:01.035Z',
            'added' => [
              {
                'id' => nil,
                'name' => 'Test vulnerability with override',
                'uuid' => new_uuid,
                'severity' => 'high'
              }
            ],
            'fixed' => []
          }
        }
      end

      before do
        stub_report(mock_report)
      end

      it 'returns the report with overridden severity' do
        expected_report = {
          status: :parsed,
          data: {
            'base_report_created_at' => nil,
            'base_report_out_of_date' => false,
            'head_report_created_at' => '2023-01-18T11:30:01.035Z',
            'added' => [
              {
                'id' => nil,
                'name' => 'Test vulnerability with override',
                'uuid' => new_uuid,
                'severity' => 'high',
                'state' => 'detected',
                'severity_override' => severity_override_data
              }
            ],
            'fixed' => []
          }
        }
        expect(report).to eq(expected_report)
      end
    end

    context 'when the given report type is valid' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:confirmed_finding) { create(:vulnerabilities_finding, :confirmed, severity: :critical) }
      let_it_be(:dismissed_finding) { create(:vulnerabilities_finding, :dismissed, severity: :medium) }

      let_it_be(:new_uuid) { SecureRandom.uuid }
      let(:confirmed_uuid) { confirmed_finding.uuid }
      let(:dismissed_uuid) { dismissed_finding.uuid }

      where(:report_type, :mr_report_method) do
        'sast'                | :compare_sast_reports
        'secret_detection'    | :compare_secret_detection_reports
        'container_scanning'  | :compare_container_scanning_reports
        'dependency_scanning' | :compare_dependency_scanning_reports
        'dast'                | :compare_dast_reports
        'coverage_fuzzing'    | :compare_coverage_fuzzing_reports
        'api_fuzzing'         | :compare_api_fuzzing_reports
      end

      with_them do
        let(:mock_report) do
          {
            status: report_status,
            data: {
              'base_report_created_at' => nil,
              'base_report_out_of_date' => false,
              'head_report_created_at' => '2023-01-18T11:30:01.035Z',
              'added' => [
                {
                  'id' => nil,
                  'name' => 'Test vulnerability 1',
                  'uuid' => new_uuid,
                  'severity' => 'critical',
                  'severity_override' => nil
                },
                {
                  'id' => nil,
                  'name' => 'Test vulnerability 2',
                  'uuid' => confirmed_uuid,
                  'severity' => 'low',
                  'severity_override' => nil
                }
              ],
              'fixed' => [
                {
                  'id' => nil,
                  'name' => 'Test vulnerability 3',
                  'uuid' => dismissed_uuid,
                  'severity' => 'low',
                  'severity_override' => nil
                }
              ]
            }
          }
        end

        context 'with no data cached' do
          it 'queues reactive caching update and returns parsing' do
            expect_reactive_cache_update_queued(report_generation_service, params.stringify_keys)

            expect(report).to eq({ status: :parsing })
          end
        end

        context 'with data cached' do
          before do
            stub_report(mock_report)
          end

          context 'when the report status is `parsing`' do
            let(:report_status) { :parsing }

            it 'returns the report' do
              expect(report).to eq(mock_report)
            end
          end

          context 'when the report status is `parsed`' do
            let(:report_status) { :parsed }
            let(:expected_report) do
              {
                status: report_status,
                data: {
                  'base_report_created_at' => nil,
                  'base_report_out_of_date' => false,
                  'head_report_created_at' => '2023-01-18T11:30:01.035Z',
                  'added' => [
                    {
                      'id' => nil,
                      'name' => 'Test vulnerability 1',
                      'uuid' => new_uuid,
                      'severity' => 'critical',
                      'state' => 'detected',
                      'severity_override' => nil
                    },
                    {
                      'id' => nil,
                      'name' => 'Test vulnerability 2',
                      'uuid' => confirmed_uuid,
                      'severity' => 'critical',
                      'state' => 'confirmed',
                      'severity_override' => nil
                    }
                  ],
                  'fixed' => [
                    {
                      'id' => nil,
                      'name' => 'Test vulnerability 3',
                      'uuid' => dismissed_uuid,
                      'severity' => 'medium',
                      'state' => 'dismissed',
                      'severity_override' => nil
                    }
                  ]
                }
              }
            end

            context 'when cached results is not latest' do
              before do
                allow(ReactiveCachingWorker).to receive(:perform_async).and_call_original
                allow_next_instance_of(Vulnerabilities::CompareSecurityReportsService) do |instance|
                  allow(instance).to receive(:latest?).and_return(false)
                end
              end

              it 'queues reactive cache update' do
                expect_reactive_cache_update_queued(report_generation_service, params.stringify_keys)

                expect(report).to eq({ status: :parsing })
              end
            end

            it 'returns all the fields along with the calculated state of the findings' do
              expect(report).to eq(expected_report)
            end
          end
        end
      end
    end
  end
end
