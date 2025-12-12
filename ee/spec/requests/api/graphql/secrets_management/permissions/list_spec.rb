# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'List project secrets permissions', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be(:project_group) { create(:group) }
  let(:error_message) do
    /The resource that you are attempting to access does not exist or you don't have permission to perform this action/i
  end

  let_it_be_with_reload(:project) { create(:project, group: project_group) }
  let_it_be(:current_user) { create(:user) }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:query_name) { :secret_permissions }
  let(:resource) { project }
  let(:resource_path) { project.full_path }
  let(:member_role_namespace) { project.group }
  let(:service_class) { SecretsManagement::ProjectSecretsPermissions::ListService }

  let(:shared_resource) { create(:group) }

  let!(:project_group_link) do
    create(:project_group_link, project: project, group: shared_resource, group_access: Gitlab::Access::DEVELOPER)
  end

  let(:query) do
    graphql_query_for(
      query_name,
      { project_path: resource_path },
      "nodes { #{all_graphql_fields_for(Types::SecretsManagement::Permissions::SecretPermissionType, max_depth: 2)} }"
    )
  end

  def provision_secrets_manager(secrets_manager, user)
    provision_project_secrets_manager(secrets_manager, user)
  end

  def update_permission(user:, actions:, principal:, expired_at: nil)
    update_project_secrets_permission(
      user: user,
      project: project,
      actions: actions,
      principal: principal,
      expired_at: expired_at
    )
  end

  subject(:post_graphql_query) { post_graphql(query, current_user: current_user) }

  context 'when secrets manager is active' do
    let!(:other_user) { create(:user) }
    let!(:member_role) { create(:member_role, namespace: member_role_namespace) }

    let(:expired_at) { 2.days.from_now.iso8601 }

    before do
      resource.add_maintainer(other_user)
      provision_secrets_manager(secrets_manager, current_user)

      update_permission(
        user: current_user, actions: %w[write read delete],
        principal: { id: other_user.id, type: 'User' }, expired_at: expired_at
      )
      update_permission(
        user: current_user, actions: %w[write read delete],
        principal: { id: Gitlab::Access::REPORTER, type: 'Role' }
      )
      update_permission(
        user: current_user, actions: %w[write read delete],
        principal: { id: member_role.id, type: 'MemberRole' }
      )
      update_permission(
        user: current_user, actions: %w[write read delete],
        principal: { id: shared_resource.id, type: 'Group' }
      )
    end

    shared_examples 'returns secrets permissions successfully' do
      it 'returns secrets permissions' do
        post_graphql_query

        expect(response).to have_gitlab_http_status(:success)

        expected_permissions = %q(["create", "delete", "read", "update"])
        expect(graphql_data_at(query_name, :nodes))
          .to include(
            a_graphql_entity_for(
              principal: a_graphql_entity_for(
                type: "ROLE",
                id: Gitlab::Access::OWNER.to_s
              ),
              permissions: expected_permissions
            ),
            a_graphql_entity_for(
              principal: a_graphql_entity_for(
                type: "USER",
                id: other_user.id.to_s
              ),
              permissions: expected_permissions,
              granted_by: a_graphql_entity_for(current_user),
              expired_at: expired_at.to_date.iso8601
            ),
            a_graphql_entity_for(
              principal: a_graphql_entity_for(
                type: "ROLE",
                id: Gitlab::Access::REPORTER.to_s
              ),
              permissions: expected_permissions,
              granted_by: a_graphql_entity_for(current_user)
            ),
            a_graphql_entity_for(
              principal: a_graphql_entity_for(
                type: "MEMBER_ROLE",
                id: member_role.id.to_s
              ),
              permissions: expected_permissions,
              granted_by: a_graphql_entity_for(current_user)
            ),
            a_graphql_entity_for(
              principal: a_graphql_entity_for(
                type: "GROUP",
                id: shared_resource.id.to_s
              ),
              permissions: expected_permissions,
              granted_by: a_graphql_entity_for(current_user)
            )
          )
      end
    end

    context 'and user is a maintainer' do
      before do
        resource.add_maintainer(current_user)
      end

      it_behaves_like 'returns secrets permissions successfully'
    end

    context 'and user is an owner' do
      before do
        resource.add_owner(current_user)
      end

      it_behaves_like 'returns secrets permissions successfully'
    end

    context 'and the user is not allowed to read secrets permissions' do
      it 'returns an error' do
        post_graphql_query

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to include(a_hash_including('message' => error_message))
      end
    end

    context 'and service results to a failure' do
      it 'returns the service error' do
        expect_next_instance_of(service_class) do |service|
          result = ServiceResponse.error(message: 'some error')
          expect(service).to receive(:execute).and_return(result)
        end

        resource.add_owner(current_user)
        post_graphql_query

        expect(graphql_errors).to include(a_hash_including('message' => 'some error'))
      end
    end

    context "when the project does not exist" do
      let(:resource_path) { 'non/existent/resource' }

      it 'returns an error' do
        resource.add_owner(current_user)
        post_graphql_query

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to include(a_hash_including('message' => error_message))
      end
    end
  end

  context 'when secrets manager is not active' do
    it 'returns a GraphQL error with the error message' do
      resource.add_owner(current_user)
      post_graphql_query

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_data_at(query_name)).to be_nil
      expect(graphql_errors).to include(
        a_hash_including('message' => "Secrets manager is not active")
      )
    end
  end
end
