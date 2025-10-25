# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- This is pentest suite with so many combination scenarios
RSpec.describe 'Secrets Manager Access Control', :gitlab_secrets_manager, feature_category: :secrets_management do
  include ProjectForksHelper

  let_it_be(:namespace_one) { create(:namespace) }
  let_it_be(:namespace_two) { create(:namespace) }

  let_it_be_with_reload(:project) { create(:project, :repository, namespace: namespace_one) }
  let_it_be_with_reload(:project_in_same_namespace) { create(:project, :repository, namespace: namespace_one) }
  let_it_be_with_reload(:project_in_different_namespace) { create(:project, :repository, namespace: namespace_two) }

  let_it_be(:project_owner) { create(:user, owner_of: project) }
  let_it_be(:forked_project_owner) { project_owner }
  let_it_be(:project_developer) { create(:user, developer_of: project) }
  let_it_be(:owner_of_project_in_same_namespace) { create(:user, owner_of: project_in_same_namespace) }
  let_it_be(:owner_of_project_in_different_namespace) { create(:user, owner_of: project_in_different_namespace) }

  let_it_be(:forked_project) { fork_project(project, project_owner, repository: true) }

  let_it_be(:merge_request) do
    create(:merge_request, source_project: forked_project, source_branch: 'feature', target_project: project,
      target_branch: 'master')
  end

  let_it_be_with_refind(:project_secrets_manager) { create(:project_secrets_manager, project: project) }
  let_it_be_with_refind(:secrets_manager_of_project_in_same_namespace) do
    create(:project_secrets_manager, project: project_in_same_namespace)
  end

  let_it_be_with_refind(:secrets_manager_of_project_in_different_namespace) do
    create(:project_secrets_manager, project: project_in_different_namespace)
  end

  let_it_be_with_refind(:secrets_manager_of_forked_project) do
    create(:project_secrets_manager, project: forked_project)
  end

  let_it_be_with_refind(:project_pipeline) do
    create(
      :ci_pipeline,
      project: project,
      sha: project.commit.id,
      ref: project.default_branch,
      status: 'success',
      user: project_developer
    )
  end

  let_it_be_with_refind(:pipeline_of_project_in_same_namespace) do
    create(
      :ci_pipeline,
      project: project_in_same_namespace,
      sha: project_in_same_namespace.commit.id,
      ref: project_in_same_namespace.default_branch,
      status: 'success',
      user: owner_of_project_in_same_namespace
    )
  end

  let_it_be_with_refind(:pipeline_of_project_in_different_namespace) do
    create(
      :ci_pipeline,
      project: project_in_different_namespace,
      sha: project_in_different_namespace.commit.id,
      ref: project_in_different_namespace.default_branch,
      status: 'success',
      user: owner_of_project_in_different_namespace
    )
  end

  let_it_be_with_refind(:merge_request_pipeline_from_forked_project_running_in_original_project) do
    create(
      :ci_pipeline,
      source: :merge_request_event,
      merge_request: merge_request,
      project: project,
      ref: merge_request.ref_path,
      status: 'success',
      user: project_owner
    )
  end

  let_it_be_with_refind(:merge_request_pipeline_from_forked_project_running_in_forked_project) do
    create(
      :ci_pipeline,
      source: :merge_request_event,
      merge_request: merge_request,
      project: forked_project,
      ref: merge_request.ref_path,
      status: 'success',
      user: project_owner
    )
  end

  let(:project_build) { create(:ee_ci_build, pipeline: project_pipeline, user: project_developer) }
  let(:build_of_project_in_same_namespace) do
    create(:ee_ci_build, pipeline: pipeline_of_project_in_same_namespace, user: owner_of_project_in_same_namespace)
  end

  let(:build_of_project_in_different_namespace) do
    create(:ee_ci_build, pipeline: pipeline_of_project_in_different_namespace,
      user: owner_of_project_in_different_namespace)
  end

  let(:forked_project_build_running_in_original_project) do
    create(:ee_ci_build, pipeline: merge_request_pipeline_from_forked_project_running_in_original_project,
      user: project_owner)
  end

  let(:forked_project_build_running_in_forked_project) do
    create(:ee_ci_build, pipeline: merge_request_pipeline_from_forked_project_running_in_forked_project,
      user: project_owner)
  end

  def build_secrets_manager_jwt(user:, project:)
    SecretsManagement::SecretsManagerJwt.new(current_user: user, project: project).encoded
  end

  def build_user_jwt(user:, project:)
    SecretsManagement::UserJwt.new(current_user: user, project: project).encoded
  end

  describe 'JWT Authentication Scenarios' do
    using RSpec::Parameterized::TableSyntax

    before do
      clean_all_kv_secrets_engines
      provision_project_secrets_manager(project_secrets_manager, project_owner)
      provision_project_secrets_manager(secrets_manager_of_project_in_same_namespace,
        owner_of_project_in_same_namespace)
      provision_project_secrets_manager(secrets_manager_of_project_in_different_namespace,
        owner_of_project_in_different_namespace)
      provision_project_secrets_manager(secrets_manager_of_forked_project, forked_project_owner)
    end

    where(:jwt_type, :jwt_scope, :auth_mount, :expected_result, :errror_message) do
      # rubocop:disable Layout/LineLength -- Test Matrix table is too long
      # JWT Type | JWT Scope                        | Auth Mount | Expected Result | Error Message
      # ---------+----------------------------------+------------+-----------------|------------------------------------------------------------------------------------------------
      :global    | :same_project                    | :global    | :success        | nil
      :global    | :same_project                    | :user      | :rejected       | 'blocked authorization with message: invalid subject for user authentication'
      :global    | :same_project                    | :pipeline  | :rejected       | 'error validating claims: claim "secrets_manager_scope" does not match any associated bound claim values'
      # ---------+----------------------------------+------------+-----------------|-----------------------------------------------------------------------------------------------
      # ---------+----------------------------------+------------+-----------------|-----------------------------------------------------------------------------------------------
      :user      | :same_project                    | :user      | :success        | nil
      :user      | :same_project                    | :global    | :rejected       | 'error validating token: invalid subject (sub) claim'
      :user      | :same_project                    | :pipeline  | :rejected       | 'error validating claims: claim "secrets_manager_scope" does not match any associated bound claim values'
      :user      | :project_in_same_namespace       | :user      | :rejected       | 'blocked authorization with message: token project_id does not match role base'
      :user      | :project_in_different_namespace  | :user      | :rejected       | 'blocked authorization with message: token project_id does not match role base'
      :user      | :forked_project                  | :user      | :rejected       | 'blocked authorization with message: token project_id does not match role base'
      # ---------+----------------------------------+------------+-----------------|------------------------------------------------------------------------------------------------
      # ---------+----------------------------------+------------+-----------------|------------------------------------------------------------------------------------------------
      :pipeline  | :same_project                    | :pipeline  | :success        | nil
      :pipeline  | :same_project                    | :global    | :rejected       | 'error validating token: invalid subject (sub) claim'
      :pipeline  | :same_project                    | :user      | :rejected       | 'blocked authorization with message: invalid subject for user authentication'
      :pipeline  | :project_in_same_namespace       | :pipeline  | :rejected       | 'error validating claims: claim "project_id" does not match any associated bound claim values'
      :pipeline  | :project_in_different_namespace  | :pipeline  | :rejected       | 'error validating claims: claim "project_id" does not match any associated bound claim values'
      :pipeline  | :forked_project                  | :pipeline  | :rejected       | 'error validating claims: claim "project_id" does not match any associated bound claim values'
      :pipeline  | :forked_project_with_pipeline_running_in_parent_project | :pipeline | :rejected | 'error validating claims: claim "project_id" does not match any associated bound claim values'
      # rubocop:enable Layout/LineLength
    end

    with_them do
      let(:jwt) do
        case jwt_scope
        when :same_project
          case jwt_type
          when :user
            build_user_jwt(user: project_owner, project: project)
          when :pipeline
            project_secrets_manager.ci_jwt(project_build)
          when :global
            build_secrets_manager_jwt(user: project_owner, project: project)
          end
        when :project_in_same_namespace
          case jwt_type
          when :user
            build_user_jwt(user: project_owner, project: project_in_same_namespace)
          when :pipeline
            secrets_manager_of_project_in_same_namespace.ci_jwt(build_of_project_in_same_namespace)
          when :global
            build_secrets_manager_jwt(user: project_owner, project: project_in_same_namespace)
          end
        when :project_in_different_namespace
          case jwt_type
          when :user
            build_user_jwt(user: project_owner, project: project_in_different_namespace)
          when :pipeline
            secrets_manager_of_project_in_different_namespace.ci_jwt(build_of_project_in_different_namespace)
          when :global
            build_secrets_manager_jwt(user: project_owner, project: project_in_different_namespace)
          end
        when :forked_project
          case jwt_type
          when :user
            build_user_jwt(user: project_owner, project: forked_project)
          when :pipeline
            secrets_manager_of_forked_project.ci_jwt(forked_project_build_running_in_forked_project)
          when :global
            build_secrets_manager_jwt(user: project_owner, project: forked_project)
          end
        when :forked_project_with_pipeline_running_in_parent_project
          case jwt_type
          when :pipeline
            secrets_manager_of_forked_project.ci_jwt(forked_project_build_running_in_original_project)
          end
        end
      end

      let(:client) do
        mount_config = case auth_mount
                       when :global
                         { auth_mount: 'gitlab_rails_jwt' }
                       when :user
                         {
                           auth_mount: project_secrets_manager.user_auth_mount,
                           role: project_secrets_manager.user_auth_role,
                           use_cel_auth: true,
                           auth_namespace: project_secrets_manager.full_project_namespace_path,
                           namespace: project_secrets_manager.full_project_namespace_path
                         }
                       when :pipeline
                         {
                           auth_mount: project_secrets_manager.ci_auth_mount,
                           role: project_secrets_manager.ci_auth_role,
                           namespace: project_secrets_manager.full_project_namespace_path,
                           auth_namespace: project_secrets_manager.full_project_namespace_path
                         }
                       end

        SecretsManagement::TestClient.new(jwt: jwt, **mount_config)
      end

      it "validates authentication boundary" do
        result = client.jwt_login

        if expected_result == :success
          expect(result[:success]).to be(true)
          expect(result[:token]).to be_present
        else
          expect(result[:success]).to be(false)
          expect(result[:error]).to include(errror_message)
        end
      end
    end
  end

  describe 'JWT Authorization Scenarios' do
    let(:project_owner_client) do
      SecretsManagement::TestClient.new(
        jwt: build_user_jwt(user: project_owner, project: project),
        auth_mount: project_secrets_manager.user_auth_mount,
        role: project_secrets_manager.user_auth_role,
        use_cel_auth: true,
        auth_namespace: project_secrets_manager.full_project_namespace_path,
        namespace: project_secrets_manager.full_project_namespace_path
      )
    end

    let(:project_developer_client) do
      SecretsManagement::TestClient.new(
        jwt: build_user_jwt(user: project_developer, project: project),
        auth_mount: project_secrets_manager.user_auth_mount,
        role: project_secrets_manager.user_auth_role,
        use_cel_auth: true,
        auth_namespace: project_secrets_manager.full_project_namespace_path,
        namespace: project_secrets_manager.full_project_namespace_path
      )
    end

    let(:project_pipeline_client) do
      SecretsManagement::TestClient.new(
        jwt: project_secrets_manager.ci_jwt(project_build),
        auth_mount: project_secrets_manager.ci_auth_mount,
        role: project_secrets_manager.ci_auth_role,
        auth_namespace: project_secrets_manager.full_project_namespace_path,
        namespace: project_secrets_manager.full_project_namespace_path
      )
    end

    let(:project_pipeline_client_with_user_defined_jwt) do
      SecretsManagement::TestClient.new(
        jwt: Gitlab::Ci::JwtV2.for_build(project_build, aud: project_secrets_manager.class.server_url),
        auth_mount: project_secrets_manager.ci_auth_mount,
        role: project_secrets_manager.ci_auth_role,
        auth_namespace: project_secrets_manager.full_project_namespace_path,
        namespace: project_secrets_manager.full_project_namespace_path
      )
    end

    let(:pipeline_client_of_project_in_same_namespace) do
      SecretsManagement::TestClient.new(
        jwt: secrets_manager_of_project_in_same_namespace.ci_jwt(build_of_project_in_same_namespace),
        auth_mount: secrets_manager_of_project_in_same_namespace.ci_auth_mount,
        role: secrets_manager_of_project_in_same_namespace.ci_auth_role,
        auth_namespace: secrets_manager_of_project_in_same_namespace.full_project_namespace_path,
        namespace: secrets_manager_of_project_in_same_namespace.full_project_namespace_path
      )
    end

    let(:pipeline_client_of_forked_project_running_in_forked_project) do
      SecretsManagement::TestClient.new(
        jwt: secrets_manager_of_forked_project.ci_jwt(forked_project_build_running_in_forked_project),
        auth_mount: secrets_manager_of_forked_project.ci_auth_mount,
        role: secrets_manager_of_forked_project.ci_auth_role,
        auth_namespace: secrets_manager_of_forked_project.full_project_namespace_path,
        namespace: secrets_manager_of_forked_project.full_project_namespace_path
      )
    end

    let(:pipeline_client_of_forked_project_running_in_original_project) do
      SecretsManagement::TestClient.new(
        jwt: secrets_manager_of_forked_project.ci_jwt(forked_project_build_running_in_original_project),
        auth_mount: secrets_manager_of_forked_project.ci_auth_mount,
        role: secrets_manager_of_forked_project.ci_auth_role,
        auth_namespace: secrets_manager_of_forked_project.full_project_namespace_path,
        namespace: secrets_manager_of_forked_project.full_project_namespace_path
      )
    end

    let(:global_secrets_manager_client) do
      SecretsManagement::SecretsManagerClient.new(
        jwt: build_secrets_manager_jwt(user: project_owner, project: project)
      )
    end

    shared_examples 'permission denied' do
      it 'raises permission denied error' do
        expect { subject }.to raise_error { |error|
          expect(error).to be_a SecretsManagement::SecretsManagerClient::ApiError
          expect(error.message).to include("permission denied")
        }
      end
    end

    context 'for actions that can only be done by secrets_manager_jwt' do
      before do
        clean_all_kv_secrets_engines
        provision_project_secrets_manager(project_secrets_manager, project_owner)
      end

      it 'enables reading project policies using SecretsManagerJwt' do
        expect(global_secrets_manager_client.list_project_policies(project_id: project.id)).to be_an(Array)
      end

      context 'when using pipeline_jwt' do
        subject do
          project_pipeline_client.list_project_policies(project_id: project.id)
        end

        it_behaves_like 'permission denied'
      end

      context 'when using user_jwt' do
        subject do
          project_owner_client.list_project_policies(project_id: project.id)
        end

        it_behaves_like 'permission denied'
      end
    end

    context 'for reading value of a secret' do
      before do
        clean_all_kv_secrets_engines
        provision_project_secrets_manager(project_secrets_manager, project_owner)
        provision_project_secrets_manager(secrets_manager_of_project_in_same_namespace,
          owner_of_project_in_same_namespace)
        provision_project_secrets_manager(secrets_manager_of_forked_project, forked_project_owner)
        create_project_secret(user: project_owner, project: project, name: 'my_secret_one', branch: 'master',
          environment: '*', value: 'my_value')
      end

      context 'when using pipeline_jwt of same project' do
        it 'reads the secret value with pipeline_jwt' do
          value = project_pipeline_client.read_kv_secret_value(
            project_secrets_manager.ci_secrets_mount_path,
            project_secrets_manager.ci_data_path("my_secret_one")
          )

          expect(value).to eq("my_value")
        end
      end

      context 'when using a custom user defined pipeline_jwt of same project' do
        subject(:read_secret) do
          project_pipeline_client_with_user_defined_jwt.read_kv_secret_value(
            project_secrets_manager.ci_secrets_mount_path,
            project_secrets_manager.ci_data_path("my_secret_one")
          )
        end

        it 'fails to read the secret value with pipeline_jwt that does not have secrets_manager_scope claim' do
          expect { read_secret }.to raise_error do |error|
            expect(error).to be_a SecretsManagement::SecretsManagerClient::AuthenticationError
            expect(error.message).to include("error validating claims: claim \"secrets_manager_scope\" is missing")
          end
        end
      end

      context 'when using pipeline_jwt of project in same namespace' do
        subject do
          pipeline_client_of_project_in_same_namespace.read_kv_secret_value(
            project_secrets_manager.ci_secrets_mount_path,
            project_secrets_manager.ci_data_path("my_secret_one")
          )
        end

        it_behaves_like 'permission denied'
      end

      context 'when using user_jwt of project owner' do
        subject do
          project_owner_client.read_kv_secret_value(
            project_secrets_manager.ci_secrets_mount_path,
            project_secrets_manager.ci_data_path("my_secret_one")
          )
        end

        it_behaves_like 'permission denied'
      end

      context 'when using pipeline_jwt of forked project' do
        subject do
          pipeline_client_of_forked_project_running_in_forked_project.read_kv_secret_value(
            project_secrets_manager.ci_secrets_mount_path,
            project_secrets_manager.ci_data_path("my_secret_one")
          )
        end

        it_behaves_like 'permission denied'
      end

      context 'when using pipeline_jwt of forked project running in original project' do
        subject do
          pipeline_client_of_forked_project_running_in_original_project.read_kv_secret_value(
            project_secrets_manager.ci_secrets_mount_path,
            project_secrets_manager.ci_data_path("my_secret_one")
          )
        end

        it_behaves_like 'permission denied'
      end
    end

    context 'for writing value of a secret' do
      before do
        clean_all_kv_secrets_engines
        provision_project_secrets_manager(project_secrets_manager, project_owner)
      end

      context 'when using user_jwt of the project owner' do
        it 'updates the secret with user_jwt of a user with access' do
          project_owner_client.update_kv_secret(
            project_secrets_manager.ci_secrets_mount_path,
            project_secrets_manager.ci_data_path("my_secret_one"),
            "my_value",
            cas: 0
          )

          expect(project_owner_client.read_secret_metadata(
            project_secrets_manager.ci_secrets_mount_path,
            project_secrets_manager.ci_data_path("my_secret_one")
          )["versions"].keys.count).to eq(1)
        end
      end

      context 'when using user_jwt of a developer in the project' do
        subject do
          project_developer_client.update_kv_secret(
            project_secrets_manager.ci_secrets_mount_path,
            project_secrets_manager.ci_data_path("my_secret_one"),
            "my_value",
            cas: 0
          )
        end

        it_behaves_like 'permission denied'
      end

      context 'when using pipeline_jwt of the project' do
        subject do
          project_pipeline_client.update_kv_secret(
            project_secrets_manager.ci_secrets_mount_path,
            project_secrets_manager.ci_data_path("my_secret_one"),
            "my_value",
            cas: 0
          )
        end

        it_behaves_like 'permission denied'
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
