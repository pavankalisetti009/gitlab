# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatusUpdateService, feature_category: :vulnerability_management do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:traversal_ids) { group.traversal_ids }

  let(:service) { described_class.new(pipeline) }

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when pipeline doesnt exist' do
      let(:service) { described_class.new(nil) }

      it 'returns nil without processing' do
        expect(execute).to be_nil
      end
    end

    context 'when project doesnt exist' do
      before do
        allow(pipeline).to receive(:project).and_return(nil)
      end

      it 'returns nil without processing' do
        expect(execute).to be_nil
      end
    end

    context 'when post_pipeline_analyzer_status_updates feature flag is disabled' do
      before do
        stub_feature_flags(post_pipeline_analyzer_status_updates: false)
      end

      it 'returns nil without processing' do
        expect(execute).to be_nil
      end
    end

    context 'when post_pipeline_analyzer_status_updates feature flag is enabled' do
      context 'when pipeline and project are present' do
        context 'with various security jobs' do
          let!(:sast_build) { create(:ci_build, :sast, :success, pipeline: pipeline) }
          let!(:dependency_scanning_build) { create(:ci_build, :dependency_scanning, :canceled, pipeline: pipeline) }
          let!(:container_scanning_build) { create(:ci_build, :container_scanning, :skipped, pipeline: pipeline) }
          let!(:secret_detection_build) { create(:ci_build, :secret_detection, :success, pipeline: pipeline) }

          let!(:kics_build) do
            build = create(:ci_build, :success, pipeline: pipeline, name: 'kics-iac-sast')
            setup_build_reports(build, [:sast])
            build
          end

          let!(:advanced_sast_build) do
            build = create(:ci_build, :success, pipeline: pipeline, name: 'gitlab-advanced-sast')
            setup_build_reports(build, [:sast])
            build
          end

          it 'creates new records for analyzers in the pipeline' do
            expect { execute }.to change { Security::AnalyzerProjectStatus.count }.from(0).to(6)

            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast).status)
              .to eq('success')
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :container_scanning).status)
              .to eq('failed')
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :secret_detection).status)
              .to eq('success')
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast_iac).status)
              .to eq('success')
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast_advanced).status)
              .to eq('success')
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :dependency_scanning)
              .status).to eq('failed')
          end

          it 'updates existing records for analyzers in the pipeline' do
            sast_status = create(:analyzer_project_status, project: project, analyzer_type: :sast,
              status: :not_configured)
            ds_status = create(:analyzer_project_status, project: project, analyzer_type: :dependency_scanning,
              status: :success)

            expect { execute }.to change { sast_status.reload.status }.from('not_configured').to('success')
              .and change { ds_status.reload.status }.from('success').to('failed')
          end

          it 'updates existing records not in the pipeline to not_configured' do
            existing_dast_status = create(:analyzer_project_status, project: project, analyzer_type: :dast,
              status: :success)

            expect { execute }.to change { existing_dast_status.reload.status }.from('success').to('not_configured')
          end
        end

        context 'with multiple jobs of the same analyzer group type' do
          let!(:sast_build_1) { create(:ci_build, :sast, :success, pipeline: pipeline) }
          let!(:sast_build_2) { create(:ci_build, :sast, :failed, pipeline: pipeline) }
          let!(:advanced_sast_build) do
            build = create(:ci_build, :failed, pipeline: pipeline, name: 'gitlab-advanced-sast')
            setup_build_reports(build, [:sast])
            build
          end

          it 'prioritize failed jobs' do
            expect { execute }.to change { Security::AnalyzerProjectStatus.count }.from(0).to(2)
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast).status)
              .to eq('failed')
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast_advanced).status)
              .to eq('failed')
          end
        end

        context 'with a build that has multiple security report types' do
          let!(:multi_report_build) do
            build = create(:ci_build, :success, pipeline: pipeline, name: 'multi-scanner')
            # Setup multiple report types for the build
            setup_build_reports(build, [:sast, :dast, :dependency_scanning])
            build
          end

          it 'processes all analyzer types from the single build' do
            execute

            expect(Security::AnalyzerProjectStatus.where(project: project).count).to eq(3)

            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast).status)
              .to eq('success')
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :dast).status)
              .to eq('success')
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :dependency_scanning)
              .status).to eq('success')
          end
        end

        context 'when no security jobs are found' do
          let!(:build) { create(:ci_build, :success, pipeline: pipeline) }

          it 'sets all analyzer statuses to not_configured' do
            sast_status = create(:analyzer_project_status, project: project, analyzer_type: :sast, status: :success)
            dast_status = create(:analyzer_project_status, project: project, analyzer_type: :dast, status: :failed)

            expect { execute }.to change { sast_status.reload.status }.from('success').to('not_configured')
              .and change { dast_status.reload.status }.from('failed').to('not_configured')
          end
        end

        context 'when an exception occurs' do
          before do
            allow(service).to receive(:pipeline_builds).and_raise(StandardError.new("Test error"))
          end

          it 'tracks the exception with error tracking' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception)
              .with(an_instance_of(StandardError), hash_including(project_id: project.id, pipeline_id: pipeline.id))

            execute
          end
        end
      end
    end
  end

  def setup_build_reports(build, report_types)
    options = build.options || {}
    options[:artifacts] ||= {}
    options[:artifacts][:reports] ||= {}

    report_types.each do |type|
      options[:artifacts][:reports][type] = {}
    end

    build.update!(options: options)
  end
end
