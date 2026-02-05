# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'graphql queries', feature_category: :api do
  complexity_overrides = {
    # Project management: https://gitlab.com/gitlab-org/gitlab/-/issues/584292
    'app/assets/javascripts/boards/graphql/lists_issues.query.graphql' => 540,
    'app/assets/javascripts/work_items/graphql/notes/work_item_notes_by_iid.query.graphql' => 450,
    'ee/app/assets/javascripts/boards/graphql/lists_epics_with_color.query.graphql' => 350,
    'ee/app/assets/javascripts/iterations/queries/iteration_issues_with_label_filter.query.graphql' => 290,

    # Work item query has a conditional that includes a new field, but this is only when
    # a feature flag is on. These tests do not account for conditional fields so we
    # make the limit higher while we develop https://gitlab.com/gitlab-org/gitlab/-/issues/587972
    'app/assets/javascripts/work_items/list/graphql/get_work_items_full.query.graphql' => 315,
    'ee/app/assets/javascripts/work_items/list/graphql/get_work_items_full.query.graphql' => 315,

    # Code review: https://gitlab.com/gitlab-org/gitlab/-/issues/584293
    'app/assets/javascripts/ci/merge_requests/graphql/queries/get_merge_request_pipelines.query.graphql' => 685,
    'ee/app/assets/javascripts/analytics/merge_request_analytics/graphql/queries/throughput_table.query.graphql' => 320,

    # Package registry: https://gitlab.com/gitlab-org/gitlab/-/issues/584294
    'app/assets/javascripts/packages_and_registries/package_registry/graphql/queries/get_packages.query.graphql' => 277,

    # Compliance: https://gitlab.com/gitlab-org/gitlab/-/issues/584295
    'ee/app/assets/javascripts/compliance_dashboard/components/frameworks_report/edit_framework/graphql/' \
      'compliance_frameworks_policies.query.graphql' => 270,
    'ee/app/assets/javascripts/compliance_dashboard/components/frameworks_report/edit_framework/graphql/' \
      'get_compliance_framework.query.graphql' => 300,
    'ee/app/assets/javascripts/compliance_dashboard/components/frameworks_report/graphql/' \
      'compliance_frameworks_group_list.query.graphql' => 340,

    # Security Insights: https://gitlab.com/gitlab-org/gitlab/-/issues/584296
    'ee/app/assets/javascripts/security_dashboard/graphql/queries/group_vulnerabilities.query.graphql' => 300,
    'ee/app/assets/javascripts/security_dashboard/graphql/queries/instance_vulnerabilities.query.graphql' => 290,
    'ee/app/assets/javascripts/security_dashboard/graphql/queries/project_vulnerabilities.query.graphql' => 330,

    # Security Platform Management: https://gitlab.com/gitlab-org/gitlab/-/issues/584297
    'ee/app/assets/javascripts/security_inventory/graphql/subgroups_and_projects.query.graphql' => 340,

    # Organizations: https://gitlab.com/gitlab-org/gitlab/-/issues/584299
    'app/assets/javascripts/projects/your_work/graphql/queries/user_projects.query.graphql' => 260,

    # Pipeline execution: https://gitlab.com/gitlab-org/gitlab/-/issues/584301
    'app/assets/javascripts/ci/pipelines_page/graphql/queries/get_pipelines.query.graphql' => 275
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

  complexity_overrides.each_key do |file|
    describe "complexity override for #{file}" do
      it 'references an existing file' do
        # Remove the file from the override list to pass this test.
        expect(File.exist?(Rails.root.join(file))).to be(true)
      end
    end
  end
end
