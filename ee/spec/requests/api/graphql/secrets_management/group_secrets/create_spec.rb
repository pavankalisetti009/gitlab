# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create group secret', :gitlab_secrets_manager, :freeze_time, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :group_secret_create }

  let(:secrets_manager) { create(:group_secrets_manager, group: group) }

  let(:params) do
    {
      group_path: group.full_path,
      name: 'TEST_SECRET',
      description: 'test description',
      secret: 'secret-value-123',
      environment: 'prod',
      protected: true
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_last_activity_update
    provision_group_secrets_manager(secrets_manager, current_user)
  end

  after do
    cancel_exclusive_group_secret_operation_lease(group)
  end

  context 'when current user is not part of the group' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user does not have write permissions in openbao' do
    before_all do
      group.add_maintainer(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  shared_examples_for 'a successful create request' do
    it 'creates the group secret', :aggregate_failures do
      post_mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      expect(graphql_data_at(mutation_name, :group_secret))
        .to match(a_graphql_entity_for(
          group: a_graphql_entity_for(group),
          name: params[:name],
          description: params[:description],
          environment: params[:environment],
          protected: params[:protected],
          metadata_version: 2,
          status: 'COMPLETED'
        ))
    end

    it_behaves_like 'an API request requiring an exclusive group secret operation lease'

    it_behaves_like 'internal event tracking' do
      let(:event) { 'create_group_ci_secret' }
      let(:user) { current_user }
      let(:namespace) { group }
      let(:category) { 'Mutations::SecretsManagement::GroupSecrets::Create' }
    end
  end

  context 'when current user was granted write permissions in openbao' do
    before_all do
      group.add_maintainer(current_user)
    end

    before do
      update_group_secrets_permission(
        user: current_user, group: group, actions: %w[write read], principal: {
          id: Gitlab::Access.sym_options[:maintainer], type: 'Role'
        }
      )
    end

    it_behaves_like 'a successful create request'

    context 'and service results to a failure' do
      let(:error_message) { 'some error' }
      let(:group_secret_with_error) do
        SecretsManagement::GroupSecret.new.tap { |gs| gs.errors.add(:base, error_message) }
      end

      let(:service_result) do
        ServiceResponse.error(message: error_message, payload: { group_secret: group_secret_with_error })
      end

      before do
        allow_next_instance_of(SecretsManagement::GroupSecrets::CreateService) do |service|
          allow(service).to receive(:execute).and_return(service_result)
        end
      end

      it 'returns the service error' do
        post_mutation
        expect(mutation_response['errors']).to include(error_message)
      end

      it_behaves_like 'internal event not tracked'
    end

    context 'and group_secrets_manager feature flag is disabled' do
      before do
        stub_feature_flags(group_secrets_manager: false)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end
  end

  context 'when current user is group owner' do
    before_all do
      group.add_owner(current_user)
    end

    it_behaves_like 'a successful create request'
  end
end
