# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::VulnerabilitiesPerSeverityResolver, :elastic_delete_by_query, :sidekiq_inline, feature_category: :vulnerability_management do
  include GraphqlHelpers

  subject(:resolved_metrics) do
    context = { current_user: current_user }
    context[:report_type] = report_type_filter if defined?(report_type_filter)
    context[:project_id] = project_id_filter if defined?(project_id_filter)
    args = if defined?(custom_args)
             custom_args
           else
             { start_date: Date.parse('2019-10-15'),
               end_date: Date.parse('2019-10-17') }
           end

    resolve(described_class, obj: operate_on, args: args, ctx: context)
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
          :with_read,
          report_type: config[:report_type],
          project: project,
          created_at: date,
          detected_at: date,
          severity: config[:severity]
        )
      end
    end
  end

  let_it_be(:additional_project_vulnerabilities) do
    [
      create(:vulnerability, :with_read, severity: :critical, report_type: :sast, project: project_2,
        created_at: '2019-10-15', detected_at: '2019-10-15'),
      create(:vulnerability, :with_read, severity: :low, report_type: :dast, project: project_2,
        created_at: '2019-10-15', detected_at: '2019-10-15')
    ]
  end

  describe '#resolve' do
    let(:start_date) { Date.new(2019, 10, 15) }
    let(:end_date) { Date.new(2019, 10, 21) }

    before do
      stub_licensed_features(security_dashboard: true)
      stub_feature_flags(group_security_dashboard_new: true)
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      # Ensure the migration is marked as completed so age stats are included
      set_elasticsearch_migration_to(:add_detected_at_field_to_vulnerability)
    end

    shared_examples 'returns resource not available' do
      it 'returns a resource not available error' do
        expect(resolved_metrics).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    shared_examples 'counts vulnerabilities from specified projects' do
      it 'only counts vulnerabilities from specified projects' do
        expect(resolved_metrics).not_to be_empty
        expect(resolved_metrics['critical'][:count]).to eq(6)
        expect(resolved_metrics['low'][:count]).to eq(3)
        expect(resolved_metrics['medium'][:count]).to eq(3)
        expect(resolved_metrics['high'][:count]).to eq(6)
      end
    end

    shared_examples 'counts only open vulnerabilities' do
      let_it_be(:additional_project_vulnerabilities) do
        additional_project_vulnerabilities << create(:vulnerability, :with_read, project: project, state: :resolved,
          report_type: :sast, severity: :critical, created_at: '2019-10-17', detected_at: '2019-10-17')

        additional_project_vulnerabilities << create(:vulnerability, :with_read, project: project, state: :resolved,
          report_type: :dast, severity: :critical, created_at: '2019-10-17', detected_at: '2019-10-17',
          resolved_on_default_branch: true)
      end

      it 'does not include the closed and resolved on default branch vulnerability' do
        expect(resolved_metrics.values.sum do |v|
          v[:count]
        end).to eq(
          operate_on.vulnerabilities.active.with_resolution(false).count)
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
          expect(resolved_metrics['critical'][:count]).to eq(7)
          expect(resolved_metrics['low'][:count]).to eq(4)
          expect(resolved_metrics['medium'][:count]).to eq(3)
          expect(resolved_metrics['high'][:count]).to eq(6)
        end

        it 'includes mean and median age for each severity', :aggregate_failures do
          expect(resolved_metrics['critical'][:mean_age]).to be_a(Float).and be > 0
          expect(resolved_metrics['critical'][:median_age]).to be_a(Float).and be > 0
          expect(resolved_metrics['low'][:mean_age]).to be_a(Float).and be > 0
          expect(resolved_metrics['low'][:median_age]).to be_a(Float).and be > 0
        end

        it_behaves_like 'counts only open vulnerabilities'

        context 'without date parameters' do
          let(:custom_args) { {} }

          it 'returns vulnerability metrics data for all vulnerabilities' do
            expect(resolved_metrics).not_to be_empty
            expect(resolved_metrics['critical'][:count]).to eq(7)
            expect(resolved_metrics['low'][:count]).to eq(4)
            expect(resolved_metrics['medium'][:count]).to eq(3)
            expect(resolved_metrics['high'][:count]).to eq(6)
          end
        end

        context 'with only start_date provided' do
          let(:custom_args) { { start_date: Date.parse('2019-10-16') } }

          it 'returns vulnerability metrics data filtered by start date only' do
            expect(resolved_metrics).not_to be_empty
            expect(resolved_metrics.values.sum { |v| v[:count] }).to be > 0
          end
        end

        context 'with only end_date provided' do
          let(:custom_args) { { end_date: Date.parse('2019-10-16') } }

          it 'returns vulnerability metrics data filtered by end date only' do
            expect(resolved_metrics).not_to be_empty
            expect(resolved_metrics.values.sum { |v| v[:count] }).to be >= 0
          end
        end

        context 'with project filtering' do
          let(:project_id_filter) { [project.id] }

          it_behaves_like 'counts vulnerabilities from specified projects'
        end

        context 'with report type filter' do
          let(:report_type_filter) { %w[sast] }

          it 'only counts vulnerabilities with filtered report types' do
            expect(resolved_metrics).not_to be_empty
            expect(resolved_metrics['critical'][:count]).to eq(4)
            expect(resolved_metrics['low'][:count]).to eq(3)
            expect(resolved_metrics['medium'][:count]).to eq(0)
            expect(resolved_metrics['high'][:count]).to eq(3)
          end
        end
      end

      context 'when the current user does not have access' do
        it_behaves_like 'returns resource not available'
      end
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

        it_behaves_like 'counts only open vulnerabilities'

        context 'with report type filter' do
          let(:report_type_filter) { %w[sast] }

          it 'only counts vulnerabilities with filtered report types' do
            expect(resolved_metrics).not_to be_empty
            expect(resolved_metrics['critical'][:count]).to eq(3)
            expect(resolved_metrics['low'][:count]).to eq(3)
            expect(resolved_metrics['medium'][:count]).to eq(0)
            expect(resolved_metrics['high'][:count]).to eq(3)
          end
        end
      end

      context 'when the current user does not have access' do
        it_behaves_like 'returns resource not available'
      end
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
