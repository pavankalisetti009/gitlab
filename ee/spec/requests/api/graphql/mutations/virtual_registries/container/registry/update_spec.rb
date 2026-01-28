# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update a container virtual registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }

  let(:mutation_params) do
    {
      id: id,
      name: 'New name',
      description: 'New description'
    }
  end

  let(:faulty_mutation_params) do
    {
      **mutation_params,
      name: nil
    }
  end

  let(:id) { ::Gitlab::GlobalId.as_global_id(registry.id, model_name: 'VirtualRegistries::Container::Registry') }
  let(:mutation_response) { graphql_mutation_response(:container_virtual_registry_update) }

  def container_virtual_registry_mutation(params = mutation_params)
    graphql_mutation(:containerVirtualRegistryUpdate, params)
  end

  before_all do
    group.add_owner(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
  end

  it 'updates the container virtual registry' do
    post_graphql_mutation(container_virtual_registry_mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['registry']).to match(
      a_hash_including(
        "name" => 'New name',
        "description" => 'New description'
      )
    )
  end

  it 'returns an error if the mutation params are invalid' do
    error_msg = "Variable $containerVirtualRegistryUpdateInput of type ContainerVirtualRegistryUpdateInput! " \
      "was provided invalid value for name (Expected value to not be null)"

    post_graphql_mutation(container_virtual_registry_mutation(faulty_mutation_params), current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(graphql_errors[0]['message']).to eq(error_msg)
  end

  context 'with container_virtual_registries feature flag turned off' do
    before do
      stub_feature_flags(container_virtual_registries: false)
    end

    it 'raises an exception' do
      error_msg = "The resource that you are attempting to access does " \
        "not exist or you don't have permission to perform this action"
      post_graphql_mutation(container_virtual_registry_mutation, current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end
end
