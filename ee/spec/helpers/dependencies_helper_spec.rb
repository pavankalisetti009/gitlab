# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependenciesHelper, feature_category: :dependency_management do
  shared_examples 'a helper method that returns shared dependencies data' do
    it 'returns data shared between all views' do
      is_expected.to include(
        has_dependencies: 'false',
        documentation_path: a_string_including("user/application_security/dependency_list/index"),
        empty_state_svg_path: match(%r{illustrations/Dependency-list-empty-state.*\.svg})
      )
    end
  end

  describe '#project_dependencies_data' do
    let_it_be(:project) { build_stubbed(:project) }

    subject { helper.project_dependencies_data(project) }

    it_behaves_like 'a helper method that returns shared dependencies data'

    it 'returns the exepected data' do
      is_expected.to include(
        endpoint: "/#{project.full_path}/-/dependencies.json",
        export_endpoint: "/api/v4/projects/#{project.id}/dependency_list_exports",
        vulnerabilities_endpoint: "/api/v4/occurrences/vulnerabilities"
      )
    end
  end

  describe '#group_dependencies_data' do
    let_it_be(:group) { build_stubbed(:group, traversal_ids: [1]) }
    let(:below_group_limit) { true }

    subject { helper.group_dependencies_data(group, below_group_limit) }

    it_behaves_like 'a helper method that returns shared dependencies data'

    it 'returns the expected data' do
      is_expected.to include(
        endpoint: "/groups/#{group.full_path}/-/dependencies.json",
        licenses_endpoint: "/groups/#{group.full_path}/-/dependencies/licenses",
        locations_endpoint: "/groups/#{group.full_path}/-/dependencies/locations",
        export_endpoint: "/api/v4/groups/#{group.id}/dependency_list_exports",
        vulnerabilities_endpoint: "/api/v4/occurrences/vulnerabilities",
        below_group_limit: "true"
      )
    end
  end

  describe '#explore_dependencies_data' do
    let_it_be(:organization) { build_stubbed(:organization) }
    let(:page_info) do
      {
        type: 'cursor',
        has_next_page: true,
        has_previous_page: false,
        start_cursor: nil,
        current_cursor: 'current_cursor',
        end_cursor: 'next_page_cursor'
      }
    end

    subject { helper.explore_dependencies_data(organization, page_info) }

    it_behaves_like 'a helper method that returns shared dependencies data'

    it 'returns the expected data' do
      is_expected.to include(
        page_info: page_info,
        endpoint: "/explore/dependencies.json",
        licenses_endpoint: nil,
        locations_endpoint: nil,
        export_endpoint: "/api/v4/organizations/#{organization.id}/dependency_list_exports",
        vulnerabilities_endpoint: nil,
        below_group_limit: "false"
      )
    end
  end
end
