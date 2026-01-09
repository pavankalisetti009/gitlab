# frozen_string_literal: true

RSpec.shared_examples 'a GraphQL mutation for updating secrets permissions' do |resource_type|
  # Note: The including spec must define:
  # - resource (the project or group)
  # - current_user (the user making the request)
  # - mutation_name (the GraphQL mutation name)
  # - secrets_manager (the secrets manager instance)
  # - provision_secrets_manager (method to provision the secrets manager)
  # - params (the mutation parameters)
  # - service_class (the service class for deleting permissions)
  # - feature_flag_name (the feature flag name to check)
  # - update_permission (method to setup and create the permission to delete)

  let_it_be(:other_user) { create(:user) }

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }
  let(:actions) { %w[READ WRITE] }
  let(:expired_at) { 1.week.from_now.to_date.iso8601 }
  let(:principal) { other_user }
  let(:principal_type) { 'USER' }
  let(:principal_params) { { id: principal.id, type: principal_type } }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when secrets manager is enabled' do
    before do
      provision_secrets_manager(secrets_manager, current_user)
    end

    context "and current user is not part of the #{resource_type}" do
      let_it_be(:user) { create(:user) }

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    context "and current user is not the #{resource_type} owner" do
      before do
        resource.add_maintainer(current_user)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    shared_examples_for 'a successful update' do
      it 'updates the secrets permission' do
        post_mutation
        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        expect(graphql_data_at(mutation_name, :secrets_permission))
          .to match(a_graphql_entity_for(
            principal: a_graphql_entity_for(
              id: principal.id.to_s,
              type: principal_type
            ),
            actions: actions,
            expired_at: expired_at
          ))
      end

      it_behaves_like "an API request requiring an exclusive #{resource_type} secret operation lease"
    end

    context "and current user is the #{resource_type} owner" do
      before do
        resource.add_owner(current_user)
      end

      context 'and principal is a User' do
        before do
          resource.add_developer(other_user)
        end

        it_behaves_like 'a successful update'
      end

      context 'and principal is a Group' do
        let(:principal_group) { shared_group }
        let(:principal) { principal_group }
        let(:principal_type) { 'GROUP' }

        let(:principal_params) do
          { group_path: principal_group.full_path, type: principal_type }
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
        it 'returns the service error' do
          expect_next_instance_of(service_class) do |service|
            result = ServiceResponse.error(message: 'some error')
            expect(service).to receive(:execute).and_return(result)
          end

          post_mutation

          expect(mutation_response['errors']).to include('some error')
        end
      end
    end
  end

  context "and feature flag is disabled" do
    before do
      stub_feature_flags(feature_flag_name => false)
      resource.add_owner(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end
end
