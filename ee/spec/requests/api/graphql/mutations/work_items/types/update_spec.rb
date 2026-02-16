# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating a work item type', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }
  let_it_be(:work_item_type) { create(:work_item_type, :issue) }

  let(:updated_name) { 'Updated Work Item Type Name' }
  let(:updated_icon_name) { 'updated-icon-name' }
  let(:params) do
    {
      id: work_item_type.to_global_id.to_s,
      full_path: group.full_path,
      name: updated_name,
      icon_name: updated_icon_name
    }
  end

  let(:mutation) { graphql_mutation(:work_item_type_update, params) }
  let(:mutation_response) { graphql_mutation_response(:work_item_type_update) }

  before do
    stub_feature_flags(work_item_configurable_types: true)
  end

  it 'returns work item type' do
    post_graphql_mutation(mutation, current_user: user)

    expect(response).to have_gitlab_http_status(:success)
    expect_graphql_errors_to_be_empty

    expect(mutation_response['workItemType']).to match(
      a_hash_including(
        'id' => work_item_type.to_global_id.to_s,
        'name' => work_item_type.name,
        'iconName' => work_item_type.icon_name
      )
    )
  end

  context 'when work item type ID is not provided' do
    let(:params) { super().except(:id) }

    it 'returns a validation error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to include(
        a_hash_including(
          'message' => a_string_matching(/Expected value to not be null/)
        )
      )
    end
  end

  context 'when work item type does not exist' do
    let(:params) { super().merge(id: "gid://gitlab/WorkItems::Type/999") }

    it 'returns work item type not found error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(mutation_response['workItemType']).to be_nil
      expect(mutation_response['errors']).to include('Work item type not found')
    end
  end

  context 'when full_path is not provided' do
    let(:params) { super().except(:full_path) }

    it 'returns work item type' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      expect(mutation_response['workItemType']).to match(
        a_hash_including(
          'id' => work_item_type.to_global_id.to_s,
          'name' => work_item_type.name,
          'iconName' => work_item_type.icon_name
        )
      )
    end
  end

  context 'when full_path is not valid' do
    let(:params) { super().merge(full_path: subgroup.full_path) }

    it 'returns invalid container error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(mutation_response['workItemType']).to be_nil
      expect(mutation_response['errors']).to include(
        'Work item types can only be updated at the root group or organization level'
      )
    end
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(work_item_configurable_types: false)
    end

    it 'returns feature not available error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(mutation_response['workItemType']).to be_nil
      expect(mutation_response['errors']).to include('Feature not available')
    end
  end
end
