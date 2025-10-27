# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::InventoryFilters::ProjectsFinderService, feature_category: :security_asset_inventories do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project1) { create(:project, namespace: group, name: "Project 1111") }
  let_it_be(:project2) { create(:project, namespace: group, name: "Project 2222") }
  let_it_be(:project3) { create(:project, namespace: subgroup, name: "Project 3333") }
  let_it_be(:archived_project) { create(:project, :archived, namespace: group, name: "Archived Project") }
  let_it_be(:other_project) { create(:project) }

  let_it_be(:inventory_filter1) do
    create(:security_inventory_filters,
      project: project1,
      traversal_ids: group.traversal_ids,
      critical: 5,
      high: 10,
      medium: 15,
      low: 20,
      sast: :success,
      secret_detection: :failed,
      dependency_scanning: :not_configured
    )
  end

  let_it_be(:inventory_filter2) do
    create(:security_inventory_filters,
      project: project2,
      traversal_ids: group.traversal_ids,
      critical: 0,
      high: 2,
      medium: 5,
      low: 10,
      sast: :failed,
      secret_detection: :success,
      dependency_scanning: :success
    )
  end

  let_it_be(:inventory_filter3) do
    create(:security_inventory_filters,
      project: project3,
      traversal_ids: subgroup.traversal_ids,
      critical: 3,
      high: 7,
      medium: 5,
      low: 1,
      sast: :not_configured,
      secret_detection: :success,
      dependency_scanning: :failed
    )
  end

  let_it_be(:archived_filter) do
    create(:security_inventory_filters,
      archived: true,
      project: archived_project,
      traversal_ids: group.traversal_ids,
      critical: 3,
      high: 7,
      medium: 5,
      low: 1,
      sast: :success,
      secret_detection: :success,
      dependency_scanning: :failed
    )
  end

  let_it_be(:other_inventory_filter) do
    create(:security_inventory_filters,
      project: other_project,
      project_name: 'Other Project',
      traversal_ids: [other_project.namespace.id],
      critical: 10
    )
  end

  let(:service) { described_class.new(namespace: namespace, params: params) }
  let(:namespace) { group }
  let(:params) { {} }

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'without filters or pagination' do
      it 'returns all relevant project ids' do
        result = execute
        expect(result[:ids]).to contain_exactly(project1.id, project2.id, project3.id)
      end

      it 'returns pagination info' do
        result = execute
        expect(result[:page_info]).to include(
          has_next_page: false,
          has_previous_page: false,
          start_cursor: be_present,
          end_cursor: be_present
        )
      end

      it 'does not include projects outside the namespace' do
        result = execute
        expect(result[:ids]).not_to include(other_project.id)
      end

      it 'does not include archived projects' do
        result = execute
        expect(result[:ids]).not_to include(archived_project.id)
      end
    end

    context 'with vulnerability count filters' do
      context 'when filtering by critical severity' do
        let(:params) do
          {
            vulnerability_count_filters: [
              { severity: 'critical', operator: 'greater_than_or_equal_to', count: 3 }
            ]
          }
        end

        it 'returns projects matching the criteria' do
          result = execute
          expect(result[:ids]).to contain_exactly(project1.id, project3.id)
        end
      end

      context 'when filtering with multiple severity conditions' do
        let(:params) do
          {
            vulnerability_count_filters: [
              { severity: 'critical', operator: 'less_than_or_equal_to', count: 5 },
              { severity: 'high', operator: 'greater_than_or_equal_to', count: 7 }
            ]
          }
        end

        it 'applies all conditions (AND logic)' do
          result = execute
          expect(result[:ids]).to contain_exactly(project1.id, project3.id)
        end
      end

      context 'when filtering with equal_to operator' do
        let(:params) do
          {
            vulnerability_count_filters: [
              { severity: 'medium', operator: 'equal_to', count: 5 }
            ]
          }
        end

        it 'returns projects with exact count' do
          result = execute
          expect(result[:ids]).to contain_exactly(project2.id, project3.id)
        end
      end
    end

    context 'with security analyzer filters' do
      context 'when filtering by single analyzer' do
        let(:params) do
          {
            security_analyzer_filters: [
              { analyzer_type: 'sast', status: 'success' }
            ]
          }
        end

        it 'returns projects with matching analyzer status' do
          result = execute
          expect(result[:ids]).to contain_exactly(project1.id)
        end
      end

      context 'when filtering by multiple analyzers' do
        let(:params) do
          {
            security_analyzer_filters: [
              { analyzer_type: 'secret_detection', status: 'success' },
              { analyzer_type: 'dependency_scanning', status: 'failed' }
            ]
          }
        end

        it 'applies all conditions (AND logic)' do
          result = execute
          expect(result[:ids]).to contain_exactly(project3.id)
        end
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
        result = execute
        expect(result[:ids]).to contain_exactly(project3.id)
      end
    end

    context 'with search filter' do
      let(:params) { { search: '1111' } }

      it 'returns only projects matching the search term' do
        result = execute
        expect(result[:ids]).to contain_exactly(project1.id)
      end

      context 'when search term partially matches multiple projects' do
        let(:params) { { search: 'Project' } }

        it 'returns all matching projects' do
          result = execute

          expect(result[:ids]).to contain_exactly(project1.id, project2.id, project3.id)
        end
      end

      context 'when search term matches no projects' do
        let(:params) { { search: 'NonExistent' } }

        it 'returns empty results' do
          result = execute
          expect(result[:ids]).to be_empty
        end
      end
    end

    context 'with search and other filters combined' do
      let(:params) do
        {
          search: 'Project',
          vulnerability_count_filters: [
            { severity: 'critical', operator: 'greater_than_or_equal_to', count: 3 }
          ]
        }
      end

      it 'applies all filters together' do
        result = execute
        expect(result[:ids]).to contain_exactly(project1.id, project3.id)
      end
    end

    context 'when no results match filters' do
      let(:params) do
        {
          vulnerability_count_filters: [
            { severity: 'critical', operator: 'greater_than_or_equal_to', count: 100 }
          ]
        }
      end

      it 'returns empty results with default page info' do
        result = execute

        expect(result[:ids]).to be_empty
        expect(result[:page_info]).to include(
          has_next_page: false,
          has_previous_page: false,
          start_cursor: nil,
          end_cursor: nil
        )
      end
    end

    context 'with first parameter' do
      let(:params) { { first: 2 } }

      it 'returns limited results in ascending order' do
        result = execute

        expect(result[:ids].size).to eq(2)
        expect(result[:ids]).to eq(result[:ids].sort)
      end

      it 'indicates next page availability' do
        result = execute

        expect(result[:page_info]).to include(
          has_next_page: true,
          has_previous_page: false
        )
      end
    end

    context 'with last parameter' do
      let(:params) { { last: 2 } }

      it 'returns limited results' do
        result = execute

        expect(result[:ids].size).to eq(2)
      end

      it 'indicates previous page availability when more records exist' do
        result = execute

        expect(result[:page_info]).to include(
          has_next_page: false,
          has_previous_page: true
        )
      end
    end

    context 'with after cursor' do
      let(:cursor) { Base64.urlsafe_encode64({ 'project_id' => project1.id, 'id' => inventory_filter1.id }.to_json) }
      let(:params) { { first: 2, after: cursor } }

      it 'returns projects after the cursor' do
        result = execute
        expected_project_ids = [project1, project2, project3]
          .select { |p| p.id > project1.id }
          .map(&:id)
          .sort
          .first(2)

        expect(result[:ids]).to match_array(expected_project_ids)
      end

      it 'indicates previous page exists' do
        result = execute

        expect(result[:page_info]).to include(
          has_previous_page: true
        )
      end
    end

    context 'with before cursor' do
      let(:cursor) { Base64.urlsafe_encode64({ 'project_id' => project3.id, 'id' => inventory_filter3.id }.to_json) }
      let(:params) { { last: 2, before: cursor } }

      it 'returns projects before the cursor' do
        result = execute
        expected_project_ids = [project1, project2, project3]
          .select { |p| p.id < project3.id }
          .map(&:id)
          .sort
          .last(2)

        expect(result[:ids]).to match_array(expected_project_ids)
      end

      it 'indicates next page exists' do
        result = execute

        expect(result[:page_info]).to include(
          has_next_page: true
        )
      end
    end

    context 'with invalid cursor' do
      context 'when cursor is malformed' do
        let(:params) { { after: 'invalid-base64' } }

        it 'ignores invalid cursor and returns all results' do
          result = execute

          expect(result[:ids]).to contain_exactly(project1.id, project2.id, project3.id)
        end
      end

      context 'when cursor has unexpected format' do
        let(:cursor) { Base64.urlsafe_encode64({ 'unexpected' => 'format' }.to_json) }
        let(:params) { { after: cursor } }

        it 'raises an error for invalid cursor format' do
          expect { execute }.to raise_error(RuntimeError, /Incorrect cursor values were given/)
        end
      end
    end

    context 'with complex pagination scenarios' do
      context 'when requesting more items than available' do
        let(:params) { { first: 10 } }

        it 'returns all available items' do
          result = execute

          expect(result[:ids]).to contain_exactly(project1.id, project2.id, project3.id)
          expect(result[:page_info][:has_next_page]).to be_falsey
        end
      end

      context 'when combining filters with pagination' do
        let(:params) do
          {
            first: 1,
            vulnerability_count_filters: [
              { severity: 'critical', operator: 'greater_than_or_equal_to', count: 3 }
            ]
          }
        end

        it 'applies filters before pagination' do
          result = execute

          expect(result[:ids].size).to eq(1)
          expect([project1.id, project3.id]).to include(result[:ids].first)
          expect(result[:page_info][:has_next_page]).to be_truthy
        end
      end

      context 'when using last with before cursor' do
        let(:cursor) { Base64.urlsafe_encode64({ 'project_id' => project3.id, 'id' => inventory_filter3.id }.to_json) }
        let(:params) { { last: 1, before: cursor } }

        it 'returns the correct values' do
          result = execute

          expect(result[:ids]).to contain_exactly(project2.id)
          expect(result[:page_info][:has_next_page]).to be true
          expect(result[:page_info][:has_previous_page]).to be true
        end
      end

      context 'when using last without before cursor' do
        let(:params) { { last: 2 } }

        it 'returns the correct values' do
          result = execute

          expect(result[:ids].size).to eq(2)
          expect(result[:page_info][:has_next_page]).to be false
          expect(result[:page_info][:has_previous_page]).to be true
        end
      end
    end

    context 'with default pagination' do
      before do
        allow(Kaminari.config).to receive(:default_per_page).and_return(2)
      end

      it 'uses default page size when no pagination params provided' do
        result = execute

        expect(result[:ids].size).to eq(2)
        expect(result[:page_info][:has_next_page]).to be true
      end
    end
  end
end
