# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update Group Secrets Permission', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:mutation_name) { :group_secrets_permission_update }

  let(:secrets_manager) { create(:group_secrets_manager, group: group) }
  let(:permissions) { %w[read create update] }
  let(:expired_at) { 1.week.from_now.to_date.iso8601 }
  let(:principal) { other_user }
  let(:principal_type) { 'USER' }
  let(:principal_params) { { id: principal.id, type: principal_type } }

  let(:params) do
    {
      groupPath: group.full_path,
      principal: principal_params,
      permissions: permissions,
      expiredAt: expired_at
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when secret manager is enabled' do
    before do
      provision_group_secrets_manager(secrets_manager, current_user)
    end

    context 'when current user is not part of the group' do
      let_it_be(:user) { create(:user) }

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    context 'when current user is not the group owner' do
      before_all do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    shared_examples_for 'a successful update' do
      it 'updates the secret permission' do
        post_mutation
        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        expect(graphql_data_at(mutation_name, :secrets_permission))
          .to match(a_graphql_entity_for(
            principal: a_graphql_entity_for(
              id: principal.id.to_s,
              type: principal_type
            ),
            permissions: permissions.to_s,
            expired_at: expired_at
          ))
      end

      it_behaves_like 'an API request requiring an exclusive group secret operation lease'
    end

    context 'when current user is the group owner' do
      before_all do
        group.add_owner(current_user)
      end

      context 'when principal is a User' do
        before_all do
          group.add_developer(other_user)
        end

        it_behaves_like 'a successful update'
      end

      context 'when principal is a Group' do
        let_it_be(:principal_group) { create(:group) }

        let(:principal) { principal_group }
        let(:principal_type) { 'GROUP' }

        let(:principal_params) do
          { group_path: principal_group.full_path, type: principal_type }
        end

        before_all do
          create(:group_group_link, shared_group: group, shared_with_group: principal_group)
        end

        it_behaves_like 'a successful update'

        context 'when principal is a Group using id (backward compatibility)' do
          let(:principal_params) do
            { id: principal_group.id, type: principal_type }
          end

          it_behaves_like 'a successful update'
        end

        context 'when group_path does not exist' do
          let(:principal_params) do
            { group_path: 'non/existent/group', type: principal_type }
          end

          it 'returns an error' do
            post_mutation
            expect_graphql_errors_to_include("Group 'non/existent/group' not found")
          end
        end

        context 'when neither id nor group_path is provided' do
          let(:principal_params) do
            { type: principal_type }
          end

          it 'returns an error' do
            post_mutation
            expect_graphql_errors_to_include('Either id or group_path must be provided to identify the principal group')
          end
        end

        context 'when group_path is used with non-Group type without id' do
          let(:principal_type) { 'USER' }

          it 'returns an error' do
            post_mutation
            expect_graphql_errors_to_include('id must be provided to identify the principal')
          end
        end
      end

      context 'and service results to a failure' do
        before do
          allow_next_instance_of(SecretsManagement::GroupSecretsPermissions::UpdateService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'some error'))
          end
        end

        it 'returns the service error' do
          expect_next_instance_of(SecretsManagement::GroupSecretsPermissions::UpdateService) do |service|
            secrets_permission = SecretsManagement::GroupSecretsPermission.new
            secrets_permission.errors.add(:base, 'some error')

            result = ServiceResponse.error(message: 'some error', payload: { secrets_permission: secrets_permission })
            expect(service).to receive(:execute).and_return(result)
          end

          post_mutation

          expect(mutation_response['errors']).to include('some error')
        end
      end
    end
  end

  context 'and group_secrets_manager feature flag is disabled' do
    let(:err_message) do
      "`group_secrets_manager` feature flag is disabled."
    end

    before_all do
      stub_feature_flags(group_secrets_manager: false)
      group.add_owner(current_user)
    end

    it 'returns an error' do
      post_mutation
      expect_graphql_errors_to_include(err_message)
    end
  end
end
