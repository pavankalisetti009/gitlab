# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update project secret', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :project_secret_update }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:project_secret_attributes) do
    {
      name: 'TEST_SECRET',
      description: 'test description',
      branch: 'main',
      environment: 'prod',
      value: 'test value'
    }
  end

  let(:params) do
    {
      project_path: project.full_path,
      name: project_secret_attributes[:name],
      description: 'updated description',
      branch: 'feature',
      environment: 'staging'
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    provision_project_secrets_manager(secrets_manager, current_user)

    create_project_secret(
      **project_secret_attributes.merge(user: current_user, project: project)
    )
  end

  context 'when current user is not part of the project' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is not the project owner' do
    before_all do
      project.add_maintainer(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is the project owner' do
    before_all do
      project.add_owner(current_user)
    end

    it 'updates the project secret', :aggregate_failures do
      post_mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      expect(graphql_data_at(mutation_name, :project_secret))
        .to match(a_graphql_entity_for(
          project: a_graphql_entity_for(project),
          name: project_secret_attributes[:name],
          description: 'updated description',
          branch: 'feature',
          environment: 'staging'
        ))
    end

    context 'with partial updates' do
      let(:params) do
        {
          project_path: project.full_path,
          name: project_secret_attributes[:name],
          description: 'updated description'
        }
      end

      it 'updates only the specified fields', :aggregate_failures do
        post_mutation

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        expect(graphql_data_at(mutation_name, :project_secret))
          .to match(a_graphql_entity_for(
            name: project_secret_attributes[:name],
            description: 'updated description',
            branch: project_secret_attributes[:branch],
            environment: project_secret_attributes[:environment]
          ))

        # Can't check the value directly in GraphQL response, but we can verify it was updated
        secret_path = secrets_manager.ci_data_path(project_secret_attributes[:name])
        expect_kv_secret_to_have_value(
          project.secrets_manager.ci_secrets_mount_path,
          secret_path,
          'test value'
        )
      end
    end

    context 'with value update' do
      let(:params) do
        {
          project_path: project.full_path,
          name: project_secret_attributes[:name],
          value: 'new-secret-value'
        }
      end

      it 'updates the value', :aggregate_failures do
        post_mutation

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        # Can't check the value directly in GraphQL response, but we can verify it was updated
        secret_path = secrets_manager.ci_data_path(project_secret_attributes[:name])
        expect_kv_secret_to_have_value(
          project.secrets_manager.ci_secrets_mount_path,
          secret_path,
          'new-secret-value'
        )
      end
    end

    context 'when secret does not exist' do
      let(:params) do
        {
          project_path: project.full_path,
          name: 'NON_EXISTENT_SECRET',
          description: 'updated description'
        }
      end

      it 'returns a top-level error with message' do
        post_mutation

        expect(mutation_response).to be_nil
        expect(graphql_errors.count).to eq(1)
        expect(graphql_errors.first['message']).to eq('Project secret does not exist.')
      end
    end

    context 'and service results to a failure' do
      before do
        allow_next_instance_of(SecretsManagement::UpdateProjectSecretService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'some error'))
        end
      end

      it 'returns the service error' do
        expect_next_instance_of(SecretsManagement::UpdateProjectSecretService) do |service|
          project_secret = SecretsManagement::ProjectSecret.new
          project_secret.errors.add(:base, 'some error')

          result = ServiceResponse.error(message: 'some error', payload: { project_secret: project_secret })
          expect(service).to receive(:execute).and_return(result)
        end

        post_mutation

        expect(mutation_response['errors']).to include('some error')
      end
    end

    context 'and secrets_manager feature flag is disabled' do
      it 'returns an error' do
        stub_feature_flags(secrets_manager: false)

        post_mutation

        expect_graphql_errors_to_include("`secrets_manager` feature flag is disabled.")
      end
    end
  end
end
