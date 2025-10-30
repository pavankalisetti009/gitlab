# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::NamespaceSecurityProjectsResolver, feature_category: :security_asset_inventories do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:resolved) do
      resolve(described_class, args: params.merge({ namespace_id: namespace_global_id }),
        ctx: { current_user: current_user },
        arg_style: :internal,
        field_opts: {
          connection_extension: Gitlab::Graphql::Extensions::ExternallyPaginatedArrayExtension
        }
      )
    end

    let_it_be(:current_user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project1) { create(:project, name: 'Michael scott', namespace: group) }
    let_it_be(:project2) { create(:project, name: 'Jim Halpert', namespace: group) }
    let_it_be(:project3) { create(:project, name: 'Dwight Schrute', namespace: group) }
    let_it_be(:archived_project) { create(:project, :archived, namespace: group) }
    let_it_be(:other_group_project) { create(:project) }

    let_it_be(:inventory_filter1) do
      create(:security_inventory_filters,
        project: project1,
        critical: 5,
        high: 10,
        sast: :success,
        secret_detection: :failed
      )
    end

    let_it_be(:inventory_filter2) do
      create(:security_inventory_filters,
        project: project2,
        critical: 0,
        high: 2,
        sast: :failed,
        secret_detection: :success
      )
    end

    let_it_be(:inventory_filter3) do
      create(:security_inventory_filters,
        project: project3,
        critical: 3,
        high: 7,
        sast: :not_configured,
        secret_detection: :success
      )
    end

    let(:namespace) { group }
    let(:namespace_global_id) { namespace.to_global_id }
    let(:params) { { namespace_id: namespace_global_id } }

    before_all do
      group.add_developer(current_user)
    end

    before do
      stub_licensed_features(security_inventory: true)
    end

    context 'when user does not have read_security_inventory permission' do
      let_it_be(:guest_user) { create(:user) }
      let(:current_user) { guest_user }

      before_all do
        group.add_guest(guest_user)
      end

      it 'raises an authorization error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolved
        end
      end
    end

    context 'when user has proper permissions' do
      context 'without filters' do
        it 'returns all non-archived projects in the namespace' do
          expect(resolved.nodes).to contain_exactly(project1, project2, project3)
          expect(resolved.nodes).not_to include(archived_project)
        end

        it 'does not include projects from other namespaces' do
          expect(resolved.nodes).not_to include(other_group_project)
        end
      end

      context 'with search filter' do
        let(:params) { { search: 'Halpert' } }

        it 'returns projects matching the search term' do
          expect(resolved.nodes).to contain_exactly(project2)
        end
      end

      context 'with single vulnerability count filter' do
        let(:params) do
          {
            vulnerability_count_filters: [
              { severity: 'critical', operator: 'greater_than_or_equal_to', count: 3 }
            ]
          }
        end

        it 'returns projects matching the vulnerability count criteria' do
          expect(resolved.nodes).to contain_exactly(project1, project3)
        end
      end

      context 'with single security analyzer filter' do
        let(:params) do
          {
            security_analyzer_filters: [
              { analyzer_type: 'sast', status: 'success' }
            ]
          }
        end

        it 'returns projects matching the analyzer status' do
          expect(resolved.nodes).to contain_exactly(project1)
        end
      end

      context 'with multiple vulnerability count filters' do
        let(:params) do
          {
            vulnerability_count_filters: [
              { severity: 'critical', operator: 'greater_than_or_equal_to', count: 3 },
              { severity: 'high', operator: 'less_than_or_equal_to', count: 7 }
            ]
          }
        end

        it 'applies all filters (AND condition)' do
          expect(resolved.nodes).to contain_exactly(project3)
        end
      end

      context 'with multiple security analyzer filters' do
        let(:params) do
          {
            security_analyzer_filters: [
              { analyzer_type: 'sast', status: 'failed' },
              { analyzer_type: 'secret_detection', status: 'success' }
            ]
          }
        end

        it 'applies all filters (AND condition)' do
          expect(resolved.nodes).to contain_exactly(project2)
        end
      end

      context 'with combined vulnerability and analyzer filters' do
        let(:params) do
          {
            vulnerability_count_filters: [
              { severity: 'critical', operator: 'greater_than_or_equal_to', count: 3 }
            ],
            security_analyzer_filters: [
              { analyzer_type: 'secret_detection', status: 'success' }
            ]
          }
        end

        it 'applies all filters together' do
          expect(resolved.nodes).to contain_exactly(project3)
        end
      end

      context 'with first parameter for pagination' do
        let(:params) { { first: 2 } }

        it 'returns the first N projects' do
          expect(resolved.nodes.size).to eq(2)
        end

        it 'has correct pagination info' do
          expect(resolved).to have_attributes(
            has_next_page: true,
            has_previous_page: false
          )
        end

        it 'has start and end cursors' do
          expect(resolved.start_cursor).to be_present
          expect(resolved.end_cursor).to be_present
        end
      end

      context 'with last parameter for pagination' do
        let(:params) { { last: 2 } }

        it 'returns the last N projects' do
          expect(resolved.nodes.size).to eq(2)
        end

        it 'has correct pagination info' do
          expect(resolved).to have_attributes(
            has_next_page: false,
            has_previous_page: true
          )
        end
      end

      context 'with after cursor for pagination' do
        let(:cursor) do
          Base64.strict_encode64({
            'project_id' => project1.id,
            'id' => inventory_filter1.id,
            'traversal_ids' => inventory_filter1.traversal_ids
          }.to_json)
        end

        let(:params) { { first: 2, after: cursor } }

        it 'returns projects after the cursor' do
          expect(resolved.nodes).to contain_exactly(project2, project3)
        end

        it 'indicates previous page exists' do
          expect(resolved.has_previous_page).to be true
        end
      end

      context 'with before cursor for pagination' do
        let(:cursor) do
          Base64.strict_encode64({
            'project_id' => project3.id,
            'id' => inventory_filter3.id,
            'traversal_ids' => inventory_filter3.traversal_ids
          }.to_json)
        end

        let(:params) { { last: 2, before: cursor } }

        it 'returns projects before the cursor' do
          expect(resolved.nodes).to contain_exactly(project1, project2)
        end

        it 'indicates next page exists' do
          expect(resolved.has_next_page).to be true
        end
      end

      context 'with pagination and filters combined' do
        let(:params) do
          {
            first: 1,
            vulnerability_count_filters: [
              { severity: 'critical', operator: 'greater_than_or_equal_to', count: 3 }
            ]
          }
        end

        it 'applies filters before pagination' do
          # Should only return one of project1 or project3
          expect(resolved.nodes.size).to eq(1)
          expect([project1, project3]).to include(resolved.nodes.first)
          expect(resolved.has_next_page).to be true
        end
      end

      context 'when no projects match filters' do
        let(:params) do
          {
            vulnerability_count_filters: [
              { severity: 'critical', operator: 'greater_than_or_equal_to', count: 100 }
            ]
          }
        end

        it 'returns an empty connection with no pagination' do
          expect(resolved.nodes).to be_empty
          expect(resolved).to have_attributes(
            has_next_page: false,
            has_previous_page: false,
            start_cursor: nil,
            end_cursor: nil
          )
        end
      end

      context 'with subgroup projects' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:subgroup_project) { create(:project, namespace: subgroup) }
        let_it_be(:subgroup_inventory_filter) do
          create(:security_inventory_filters, project: subgroup_project)
        end

        it 'does not include subgroup projects by default' do
          expect(resolved.nodes).not_to include(subgroup_project)
        end

        context 'when include_subgroups is true' do
          let(:params) { { include_subgroups: true } }

          it 'include subgroup projects' do
            expect(resolved.nodes).to include(subgroup_project)
          end
        end
      end
    end
  end
end
