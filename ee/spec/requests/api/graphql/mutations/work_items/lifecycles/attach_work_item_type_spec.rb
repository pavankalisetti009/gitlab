# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Attaching a work item type to a custom lifecycle', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let_it_be(:system_defined_lifecycle) { build(:work_item_system_defined_lifecycle) }
  let_it_be(:system_defined_to_do_status) { build(:work_item_system_defined_status, :to_do) }
  let_it_be(:system_defined_in_progress_status) { build(:work_item_system_defined_status, :in_progress) }

  let_it_be(:work_item_type) { create(:work_item_type) }

  let(:params) do
    {
      namespace_path: group.full_path,
      work_item_type_id: work_item_type.to_gid,
      lifecycle_id: system_defined_lifecycle.to_gid,
      status_mappings: [
        {
          old_status_id: system_defined_to_do_status.to_gid,
          new_status_id: system_defined_in_progress_status.to_gid
        }
      ]
    }
  end

  let(:mutation) { graphql_mutation(:lifecycle_attach_work_item_type, params) }
  let(:mutation_response) { graphql_mutation_response(:lifecycle_attach_work_item_type) }

  before do
    stub_licensed_features(work_item_status: true)
  end

  it 'accepts arguments and does nothing' do
    post_graphql_mutation(mutation, current_user: user)

    expect(response).to have_gitlab_http_status(:success)
    expect_graphql_errors_to_be_empty
    expect(mutation_response['lifecycle']).to be_nil

    expect(::WorkItems::Statuses::Custom::Mapping.count).to eq(0)
  end

  context 'when custom lifecycle exists' do
    let!(:custom_lifecycle) do
      create(:work_item_custom_lifecycle, name: system_defined_lifecycle.name, namespace: group)
    end

    let(:params) do
      {
        namespace_path: group.full_path,
        work_item_type_id: work_item_type.to_gid,
        lifecycle_id: custom_lifecycle.to_gid,
        status_mappings: [
          {
            old_status_id: custom_lifecycle.default_duplicate_status.to_gid,
            new_status_id: custom_lifecycle.default_closed_status.to_gid
          }
        ]
      }
    end

    it 'accepts arguments and does nothing' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(mutation_response['lifecycle']).to be_nil

      expect(::WorkItems::Statuses::Custom::Mapping.count).to eq(0)
    end
  end

  context 'when invalid input is provided' do
    let(:params) { {} }

    it 'returns validation error for all missing required attributes' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(
        "Variable $lifecycleAttachWorkItemTypeInput of type LifecycleAttachWorkItemTypeInput! was provided invalid " \
          "value for namespacePath (Expected value to not be null), workItemTypeId (Expected value to not be null), " \
          "lifecycleId (Expected value to not be null)"
      )
    end
  end

  context 'when user is unauthorized' do
    it 'returns an error' do
      guest = create(:user, guest_of: group)

      post_graphql_mutation(mutation, current_user: guest)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(
        "The resource that you are attempting to access does not exist " \
          "or you don't have permission to perform this action"
      )
    end
  end
end
