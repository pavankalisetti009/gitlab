# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a list of work item types for a group EE', feature_category: :team_planning do
  let_it_be(:namespace) { create(:group, :private) }
  let_it_be(:developer) { create(:user, developer_of: namespace) }
  let(:parent) { namespace }
  let(:current_user) { developer }

  it_behaves_like 'graphql work item type list request spec', 'with work item types request context EE'

  it_behaves_like 'graphql work item type list request spec EE'

  context 'with custom fields widget' do
    include GraphqlHelpers

    include_context 'with group configured with custom fields'

    let(:query) do
      graphql_query_for('namespace', { 'fullPath' => group.full_path },
        query_nodes('WorkItemTypes', work_item_type_fields)
      )
    end

    let(:work_item_type_fields) do
      <<~GRAPHQL
        id
        widgetDefinitions {
          type
          ... on WorkItemWidgetDefinitionCustomFields {
            customFields {
              id
            }
          }
        }
      GRAPHQL
    end

    before do
      stub_licensed_features(custom_fields: true)
    end

    it 'returns custom fields available for each work item type' do
      post_graphql(query, current_user: current_user)

      custom_field_widgets_per_type = graphql_data_at('namespace', 'workItemTypes', 'nodes').map do |type|
        {
          work_item_type_id: type['id'],
          custom_fields_widget: type['widgetDefinitions'].find { |widget| widget['type'] == 'CUSTOM_FIELDS' }
        }
      end

      expect(custom_field_widgets_per_type).to include(
        {
          work_item_type_id: issue_type.to_gid.to_s,
          custom_fields_widget: {
            'type' => 'CUSTOM_FIELDS',
            'customFields' => [
              { 'id' => select_field.to_gid.to_s },
              { 'id' => number_field.to_gid.to_s },
              { 'id' => text_field.to_gid.to_s },
              { 'id' => multi_select_field.to_gid.to_s }
            ]
          }
        }
      )

      expect(custom_field_widgets_per_type).to include(
        {
          work_item_type_id: task_type.to_gid.to_s,
          custom_fields_widget: {
            'type' => 'CUSTOM_FIELDS',
            'customFields' => [
              { 'id' => select_field.to_gid.to_s },
              { 'id' => multi_select_field.to_gid.to_s },
              { 'id' => field_on_other_type.to_gid.to_s }
            ]
          }
        }
      )
    end
  end
end
