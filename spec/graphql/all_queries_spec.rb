# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'graphql queries', feature_category: :api do
  complexity_overrides = {
    'app/assets/javascripts/boards/graphql/lists_issues.query.graphql' => 360,
    'app/assets/javascripts/ci/merge_requests/graphql/queries/get_merge_request_pipelines.query.graphql' => 350,
    'app/assets/javascripts/packages_and_registries/package_registry/graphql/queries/get_packages.query.graphql' => 290,
    'app/assets/javascripts/projects/your_work/graphql/queries/user_projects.query.graphql' => 260,
    'app/assets/javascripts/work_items/graphql/notes/work_item_notes_by_iid.query.graphql' => 410,
    'ee/app/assets/javascripts/analytics/merge_request_analytics/graphql/queries/throughput_table.query.graphql' => 320,
    'ee/app/assets/javascripts/boards/graphql/lists_epics.query.graphql' => 350,
    'ee/app/assets/javascripts/boards/graphql/lists_epics_with_color.query.graphql' => 350,
    'ee/app/assets/javascripts/compliance_dashboard/components/frameworks_report/edit_framework/graphql/' \
      'compliance_frameworks_policies.query.graphql' => 270,
    'ee/app/assets/javascripts/compliance_dashboard/components/frameworks_report/edit_framework/graphql/' \
      'get_compliance_framework.query.graphql' => 300,
    'ee/app/assets/javascripts/compliance_dashboard/components/frameworks_report/graphql/' \
      'compliance_frameworks_group_list.query.graphql' => 340,
    'ee/app/assets/javascripts/iterations/queries/iteration_issues_with_label_filter.query.graphql' => 290,
    'ee/app/assets/javascripts/security_dashboard/graphql/queries/group_vulnerabilities.query.graphql' => 300,
    'ee/app/assets/javascripts/security_dashboard/graphql/queries/' \
      'group_vulnerabilities_with_policy_violations.query.graphql' => 300,
    'ee/app/assets/javascripts/security_dashboard/graphql/queries/instance_vulnerabilities.query.graphql' => 290,
    'ee/app/assets/javascripts/security_dashboard/graphql/queries/project_vulnerabilities.query.graphql' => 330,
    'ee/app/assets/javascripts/security_dashboard/graphql/queries/' \
      'project_vulnerabilities_with_policy_violations.query.graphql' => 330,
    'ee/app/assets/javascripts/security_inventory/graphql/subgroups_and_projects.query.graphql' => 340
  }

  describe 'complexity' do
    Gitlab::Graphql::Queries.all.each do |definition| # rubocop:disable Rails/FindEach -- Not an ActiveRecord relation
      relative_path = definition.file.delete_prefix("#{Rails.root}/") # rubocop:disable Rails/FilePath -- Can't be used to append '/'

      describe relative_path do
        it 'does not exceed complexity limit' do
          limit = complexity_overrides.fetch(relative_path, GitlabSchema::AUTHENTICATED_MAX_COMPLEXITY)

          expect(definition.complexity(GitlabSchema)).to be < limit
        end
      end
    end
  end

  describe 'overrides' do
    # Remove the file from the override list to pass this test.
    it 'contains only files that exists' do
      complexity_overrides.each_key do |file|
        expect(File.exist?(Rails.root.join(file))).to be(true)
      end
    end
  end
end
