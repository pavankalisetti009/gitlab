# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::VulnerabilitiesPerSeverityResolver, :elastic_delete_by_query, :sidekiq_inline, feature_category: :vulnerability_management do
  include GraphqlHelpers

  subject(:resolved_metrics) do
    context = { current_user: current_user }
    context[:report_type] = report_type_filter if defined?(report_type_filter)
    context[:project_id] = project_id_filter if defined?(project_id_filter)
    resolve(described_class, obj: operate_on,
      args: { start_date: Date.parse('2019-10-15'), end_date: Date.parse('2019-10-17') }, ctx: context)
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:project_2) { create(:project, namespace: group) }
  let_it_be(:project_3) { create(:project, namespace: group) }
  let_it_be(:project_4) { create(:project, namespace: group) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:vulnerabilities) do
    dates = ['2019-10-15T00:00:00Z', '2019-10-16T00:00:00Z', '2019-10-17T00:00:00Z']
    severity_report_pairs = [
      { severity: :critical, report_type: :sast },
      { severity: :critical, report_type: :dast },
      { severity: :low, report_type: :sast },
      { severity: :medium, report_type: :dependency_scanning },
      { severity: :high, report_type: :sast },
      { severity: :high, report_type: :dependency_scanning }
    ]

    dates.flat_map do |date|
      severity_report_pairs.map do |config|
        create(
          :vulnerability,
          :with_finding,
          report_type: config[:report_type],
          project: project,
          created_at: date,
          severity: config[:severity]
        )
      end
    end
  end

  let_it_be(:additional_project_vulnerabilities) do
    [
      create(:vulnerability, :with_finding, severity: :critical, report_type: :sast, project: project_2,
        created_at: '2019-10-15'),
      create(:vulnerability, :with_finding, severity: :low, report_type: :dast, project: project_2,
        created_at: '2019-10-15')
    ]
  end

  describe '#resolve' do
    let(:start_date) { Date.new(2019, 10, 15) }
    let(:end_date) { Date.new(2019, 10, 21) }

    before do
      stub_licensed_features(security_dashboard: true)
      stub_feature_flags(group_security_dashboard_new: true)
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    shared_examples 'returns resource not available' do
      it 'returns a resource not available error' do
        expect(resolved_metrics).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    shared_examples 'returns empty array' do
      context 'when new_security_dashboard_vulnerabilities_per_severity feature flag is disabled' do
        before_all do
          group.add_maintainer(current_user)
          Elastic::ProcessBookkeepingService.track!(*vulnerabilities, *additional_project_vulnerabilities)
          ensure_elasticsearch_index!
        end

        before do
          stub_feature_flags(new_security_dashboard_vulnerabilities_per_severity: false)
        end

        it 'returns an empty array connection' do
          expect(resolved_metrics).to eq({})
          expect(resolved_metrics).to be_empty
        end
      end
    end

    shared_examples 'counts vulnerabilities from specified projects' do
      it 'only counts vulnerabilities from specified projects' do
        expect(resolved_metrics).not_to be_empty
        expect(resolved_metrics['critical']).to eq(6)
        expect(resolved_metrics['low']).to eq(3)
        expect(resolved_metrics['medium']).to eq(3)
        expect(resolved_metrics['high']).to eq(6)
      end
    end

    context 'when operated on a group' do
      let(:operate_on) { group }

      context 'when the current user has access' do
        before_all do
          group.add_maintainer(current_user)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(*vulnerabilities, *additional_project_vulnerabilities)
          ensure_elasticsearch_index!
        end

        it 'returns vulnerability metrics data' do
          expect(resolved_metrics).not_to be_empty
          expect(resolved_metrics['critical']).to eq(7)
          expect(resolved_metrics['low']).to eq(4)
          expect(resolved_metrics['medium']).to eq(3)
          expect(resolved_metrics['high']).to eq(6)
        end

        context 'with project filtering' do
          let(:project_id_filter) { [project.id] }

          it_behaves_like 'counts vulnerabilities from specified projects'
        end

        context 'with report type filter' do
          let(:report_type_filter) { %w[sast] }

          it 'only counts vulnerabilities with filtered report types' do
            expect(resolved_metrics).not_to be_empty
            expect(resolved_metrics['critical']).to eq(4)
            expect(resolved_metrics['low']).to eq(3)
            expect(resolved_metrics['medium']).to eq(0)
            expect(resolved_metrics['high']).to eq(3)
          end
        end
      end

      context 'when the current user does not have access' do
        it_behaves_like 'returns resource not available'
      end

      it_behaves_like 'returns empty array'
    end

    context 'when operated on a project' do
      let(:operate_on) { project }

      context 'when the current user has access' do
        before_all do
          group.add_maintainer(current_user)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(*vulnerabilities, *additional_project_vulnerabilities)
          ensure_elasticsearch_index!
        end

        it_behaves_like 'counts vulnerabilities from specified projects'

        context 'with report type filter' do
          let(:report_type_filter) { %w[sast] }

          it 'only counts vulnerabilities with filtered report types' do
            expect(resolved_metrics).not_to be_empty
            expect(resolved_metrics['critical']).to eq(3)
            expect(resolved_metrics['low']).to eq(3)
            expect(resolved_metrics['medium']).to eq(0)
            expect(resolved_metrics['high']).to eq(3)
          end
        end
      end

      context 'when the current user does not have access' do
        it_behaves_like 'returns resource not available'
      end

      it_behaves_like 'returns empty array'
    end

    context 'when security_dashboard feature flag is disabled' do
      let(:operate_on) { group }

      before_all do
        group.add_maintainer(current_user)
      end

      before do
        stub_licensed_features(security_dashboard: false)
      end

      it_behaves_like 'returns resource not available'
    end
  end
end
