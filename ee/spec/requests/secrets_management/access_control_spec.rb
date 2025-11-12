# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- This is pentest suite with so many combination scenarios
RSpec.describe 'Secrets Manager Access Control', :gitlab_secrets_manager, feature_category: :secrets_management do
  include ProjectForksHelper

  # Helper methods (shared across all contexts)
  def build_secrets_manager_jwt(user:, project:)
    SecretsManagement::SecretsManagerJwt.new(current_user: user, project: project).encoded
  end

  def build_user_jwt(user:, project:)
    SecretsManagement::UserJwt.new(current_user: user, project: project).encoded
  end

  def build_group_user_jwt(user:, group:)
    SecretsManagement::GroupUserJwt.new(current_user: user, group: group).encoded
  end

  def build_group_secrets_manager_jwt(user:, group:)
    SecretsManagement::GroupSecretsManagerJwt.new(current_user: user, group: group).encoded
  end

  describe 'JWT Authentication Scenarios' do
    context 'with project-level authentication' do
      using RSpec::Parameterized::TableSyntax

      # Project-specific resources
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

    context 'with group-level authentication' do
      using RSpec::Parameterized::TableSyntax

      # Group-specific resources
      # Group hierarchy:
      #
      # root_group
      #   - subgroup
      #       - project_in_subgroup
      #       - child_subgroup
      #         - project_in_child_subgroup
      #   - sibling_group
      #       - project_in_sibling_group
      #
      # unrelated_group
      #   - project_in_unrelated_group

      let_it_be(:root_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: root_group) }
      let_it_be(:child_subgroup) { create(:group, parent: subgroup) }
      let_it_be(:sibling_group) { create(:group, parent: root_group) }
      let_it_be(:unrelated_group) { create(:group) }

      let_it_be(:project_in_root_group) { create(:project, :repository, namespace: root_group) }
      let_it_be(:project_in_subgroup) { create(:project, :repository, namespace: subgroup) }
      let_it_be(:project_in_child_subgroup) { create(:project, :repository, namespace: child_subgroup) }
      let_it_be(:project_in_sibling_group) { create(:project, :repository, namespace: sibling_group) }
      let_it_be(:project_in_unrelated_group) { create(:project, :repository, namespace: unrelated_group) }
      let_it_be(:forked_project_from_subgroup) { fork_project(project_in_subgroup, subgroup_owner, repository: true) }

      let_it_be(:root_group_owner) { create(:user, owner_of: root_group) }
      let_it_be(:subgroup_owner) { create(:user, owner_of: subgroup) }
      let_it_be(:child_subgroup_owner) { create(:user, owner_of: child_subgroup) }
      let_it_be(:unrelated_group_user) { create(:user, owner_of: unrelated_group) }

      let_it_be(:root_group_secrets_manager) { create(:group_secrets_manager, group: root_group) }
      let_it_be(:subgroup_secrets_manager) { create(:group_secrets_manager, group: subgroup) }

      # Group pipelines
      let_it_be(:pipeline_in_root_group_project) do
        create(:ci_pipeline, project: project_in_root_group, sha: project_in_root_group.commit.id,
          ref: project_in_root_group.default_branch, status: 'success', user: root_group_owner)
      end

      let_it_be(:pipeline_in_subgroup_project) do
        create(:ci_pipeline, project: project_in_subgroup, sha: project_in_subgroup.commit.id,
          ref: project_in_subgroup.default_branch, status: 'success', user: subgroup_owner)
      end

      let_it_be(:pipeline_in_child_subgroup_project) do
        create(:ci_pipeline, project: project_in_child_subgroup, sha: project_in_child_subgroup.commit.id,
          ref: project_in_child_subgroup.default_branch, status: 'success', user: child_subgroup_owner)
      end

      let_it_be(:pipeline_in_sibling_group_project) do
        create(:ci_pipeline, project: project_in_sibling_group, sha: project_in_sibling_group.commit.id,
          ref: project_in_sibling_group.default_branch, status: 'success', user: root_group_owner)
      end

      let_it_be(:pipeline_in_unrelated_group_project) do
        create(:ci_pipeline, project: project_in_unrelated_group, sha: project_in_unrelated_group.commit.id,
          ref: project_in_unrelated_group.default_branch, status: 'success', user: root_group_owner)
      end

      let_it_be(:forked_project_pipeline) do
        create(:ci_pipeline, project: forked_project_from_subgroup, sha: forked_project_from_subgroup.commit.id,
          ref: forked_project_from_subgroup.default_branch, status: 'success', user: subgroup_owner)
      end

      # Group builds
      let(:build_in_root_group_project) do
        create(:ee_ci_build, pipeline: pipeline_in_root_group_project, user: root_group_owner)
      end

      let(:build_in_subgroup_project) do
        create(:ee_ci_build, pipeline: pipeline_in_subgroup_project, user: subgroup_owner)
      end

      let(:build_in_child_subgroup_project) do
        create(:ee_ci_build, pipeline: pipeline_in_child_subgroup_project, user: child_subgroup_owner)
      end

      let(:build_in_sibling_group_project) do
        create(:ee_ci_build, pipeline: pipeline_in_sibling_group_project, user: root_group_owner)
      end

      let(:build_in_unrelated_group_project) do
        create(:ee_ci_build, pipeline: pipeline_in_unrelated_group_project, user: root_group_owner)
      end

      let(:forked_project_build) do
        create(:ee_ci_build, pipeline: forked_project_pipeline, user: subgroup_owner)
      end

      before do
        clean_all_kv_secrets_engines
        provision_group_secrets_manager(root_group_secrets_manager, root_group_owner)
        provision_group_secrets_manager(subgroup_secrets_manager, subgroup_owner)
      end

      where(:jwt_type, :jwt_scope, :auth_mount, :expected_result, :errror_message) do
        # rubocop:disable Layout/LineLength -- Test Matrix table is too long
        # JWT Type        | JWT Scope                        | Auth Mount      | Expected Result | Error Message
        # ----------------+----------------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------
        # Group Secrets - Global JWT
        :group_global     | :same_group                      | :group_global   | :success        | nil
        :group_global     | :same_group                      | :group_user     | :rejected       | 'blocked authorization with message: invalid subject for user authentication'
        :group_global     | :same_group                      | :group_pipeline | :rejected       | 'blocked authorization with message: invalid subject for pipeline authentication'
        # ----------------+----------------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------
        # Group Secrets - User JWT
        :group_user       | :user_in_group                   | :group_user     | :success        | nil
        :group_user       | :same_group                      | :group_global   | :rejected       | 'error validating token: invalid subject (sub) claim'
        :group_user       | :same_group                      | :group_pipeline | :rejected       | 'blocked authorization with message: invalid subject for pipeline authentication'
        :group_user       | :user_in_unrelated_group         | :group_user     | :rejected       | 'blocked authorization with message: token group_id does not match group'
        # ----------------+----------------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------
        # Group Secrets - Pipeline JWT (project_group_ids validation)
        :group_pipeline   | :project_in_own_group            | :group_pipeline | :success        | nil
        :group_pipeline   | :project_in_child_group          | :group_pipeline | :success        | nil
        :group_pipeline   | :project_in_grandchild_group     | :group_pipeline | :success        | nil
        :group_pipeline   | :project_in_own_group            | :group_global   | :rejected       | 'error validating token: invalid subject (sub) claim'
        :group_pipeline   | :project_in_own_group            | :group_user     | :rejected       | 'blocked authorization with message: invalid subject for user authentication'
        :group_pipeline   | :project_in_sibling_group        | :group_pipeline | :rejected       | 'blocked authorization with message: project does not belong to group'
        :group_pipeline   | :project_in_unrelated_group      | :group_pipeline | :rejected       | 'blocked authorization with message: project does not belong to group'
        :group_pipeline   | :project_in_parent_group         | :group_pipeline | :rejected       | 'blocked authorization with message: project does not belong to group'
        :group_pipeline   | :forked_project_to_group         | :group_pipeline | :rejected       | 'blocked authorization with message: project does not belong to group'
        :group_pipeline   | :project_missing_group_ids_claim | :group_pipeline | :rejected       | 'blocked authorization with message: missing project_group_ids claim'
        # rubocop:enable Layout/LineLength
      end

      with_them do
        let(:jwt) do
          case jwt_scope
          when :same_group
            case jwt_type
            when :group_user
              build_group_user_jwt(user: root_group_owner, group: root_group)
            when :group_pipeline
              root_group_secrets_manager.ci_jwt(build_in_root_group_project)
            when :group_global
              build_group_secrets_manager_jwt(user: root_group_owner, group: root_group)
            end
          when :project_in_own_group
            root_group_secrets_manager.ci_jwt(build_in_root_group_project)
          when :project_in_child_group
            root_group_secrets_manager.ci_jwt(build_in_subgroup_project)
          when :project_in_grandchild_group
            root_group_secrets_manager.ci_jwt(build_in_child_subgroup_project)
          when :project_in_sibling_group
            subgroup_secrets_manager.ci_jwt(build_in_sibling_group_project)
          when :project_in_unrelated_group
            root_group_secrets_manager.ci_jwt(build_in_unrelated_group_project)
          when :project_in_parent_group
            subgroup_secrets_manager.ci_jwt(build_in_root_group_project)
          when :forked_project_to_group
            subgroup_secrets_manager.ci_jwt(forked_project_build)
          when :project_missing_group_ids_claim
            JWT.encode(
              {
                iss: SecretsManagement::GroupSecretsManager.jwt_issuer,
                aud: SecretsManagement::GroupSecretsManager.server_url,
                iat: Time.now.to_i,
                exp: Time.now.to_i + 600,
                user_id: root_group_owner.id.to_s,
                project_id: project_in_subgroup.id.to_s,
                namespace_id: subgroup.id.to_s,
                sub: "project_path:#{project_in_subgroup.full_path}:ref_type:branch:ref:main",
                secrets_manager_scope: 'pipeline'
              },
              OpenSSL::PKey::RSA.new(Gitlab::CurrentSettings.ci_jwt_signing_key),
              'RS256'
            )
          when :user_in_group
            build_group_user_jwt(user: root_group_owner, group: root_group)
          when :user_in_unrelated_group
            build_group_user_jwt(user: unrelated_group_user, group: unrelated_group)
          end
        end

        let(:client) do
          mount_config = case auth_mount
                         when :group_global
                           { auth_mount: 'gitlab_rails_jwt' }
                         when :group_user
                           {
                             auth_mount: root_group_secrets_manager.user_auth_mount,
                             role: root_group_secrets_manager.user_auth_role,
                             use_cel_auth: true,
                             auth_namespace: root_group_secrets_manager.full_group_namespace_path,
                             namespace: root_group_secrets_manager.full_group_namespace_path
                           }
                         when :group_pipeline
                           # Use subgroup for most tests, but switch based on scope
                           secrets_mgr = case jwt_scope
                                         when :project_in_own_group, :project_in_child_group,
                                           :project_in_grandchild_group, :project_in_unrelated_group
                                           root_group_secrets_manager
                                         else
                                           subgroup_secrets_manager
                                         end
                           {
                             auth_mount: secrets_mgr.ci_auth_mount,
                             role: secrets_mgr.ci_auth_role,
                             use_cel_auth: true,
                             auth_namespace: secrets_mgr.full_group_namespace_path,
                             namespace: secrets_mgr.full_group_namespace_path
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

    context 'with cross-type authentication (project vs group isolation)' do
      using RSpec::Parameterized::TableSyntax

      # Cross-type resources (minimal setup for isolation tests)
      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:project) { create(:project, :repository, namespace: namespace) }
      let_it_be(:project_owner) { create(:user, owner_of: project) }
      let_it_be_with_refind(:project_secrets_manager) { create(:project_secrets_manager, project: project) }

      let_it_be(:root_group) { create(:group) }
      let_it_be(:project_in_root_group) { create(:project, :repository, namespace: root_group) }
      let_it_be(:root_group_owner) { create(:user, owner_of: root_group) }
      let_it_be(:root_group_secrets_manager) { create(:group_secrets_manager, group: root_group) }

      let_it_be_with_refind(:project_pipeline) do
        create(
          :ci_pipeline,
          project: project,
          sha: project.commit.id,
          ref: project.default_branch,
          status: 'success',
          user: project_owner
        )
      end

      let_it_be(:pipeline_in_root_group_project) do
        create(:ci_pipeline, project: project_in_root_group, sha: project_in_root_group.commit.id,
          ref: project_in_root_group.default_branch, status: 'success', user: root_group_owner)
      end

      let(:project_build) { create(:ee_ci_build, pipeline: project_pipeline, user: project_owner) }
      let(:build_in_root_group_project) do
        create(:ee_ci_build, pipeline: pipeline_in_root_group_project, user: root_group_owner)
      end

      before do
        clean_all_kv_secrets_engines
        # Provision both project and group secrets managers
        provision_project_secrets_manager(project_secrets_manager, project_owner)
        provision_group_secrets_manager(root_group_secrets_manager, root_group_owner)
      end

      where(:jwt_type, :jwt_scope, :auth_mount, :expected_result, :errror_message) do
        # rubocop:disable Layout/LineLength -- Test Matrix table is too long
        # JWT Type        | JWT Scope             | Auth Mount      | Expected Result | Error Message
        # ----------------+-----------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------
        # Group JWTs trying to access Project mounts
        :group_pipeline   | :project_in_own_group | :pipeline       | :rejected       | 'error validating claims: claim "project_id" does not match any associated bound claim values'
        :group_user       | :user_in_group        | :user           | :rejected       | 'blocked authorization with message: missing project_id'
        :group_global     | :same_group           | :global         | :success        | nil
        # ----------------+-----------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------
        # Project JWTs trying to access Group mounts
        :pipeline         | :same_project         | :group_pipeline | :rejected       | 'blocked authorization with message: missing project_group_ids claim'
        :user             | :same_project         | :group_user     | :rejected       | 'blocked authorization with message: missing group_id'
        :global           | :same_project         | :group_global   | :success        | nil
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
          when :same_group, :user_in_group
            case jwt_type
            when :group_user
              build_group_user_jwt(user: root_group_owner, group: root_group)
            when :group_global
              build_group_secrets_manager_jwt(user: root_group_owner, group: root_group)
            end
          when :project_in_own_group
            root_group_secrets_manager.ci_jwt(build_in_root_group_project)
          end
        end

        let(:client) do
          mount_config = case auth_mount
                         when :global, :group_global
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
                         when :group_user
                           {
                             auth_mount: root_group_secrets_manager.user_auth_mount,
                             role: root_group_secrets_manager.user_auth_role,
                             use_cel_auth: true,
                             auth_namespace: root_group_secrets_manager.full_group_namespace_path,
                             namespace: root_group_secrets_manager.full_group_namespace_path
                           }
                         when :group_pipeline
                           {
                             auth_mount: root_group_secrets_manager.ci_auth_mount,
                             role: root_group_secrets_manager.ci_auth_role,
                             use_cel_auth: true,
                             auth_namespace: root_group_secrets_manager.full_group_namespace_path,
                             namespace: root_group_secrets_manager.full_group_namespace_path
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
  end

  describe 'JWT Authorization Scenarios' do
    # Project authorization resources
    let_it_be(:namespace) { create(:namespace) }
    let_it_be_with_reload(:project) { create(:project, :repository, namespace: namespace) }
    let_it_be(:project_in_same_namespace) { create(:project, :repository, namespace: namespace) }
    let_it_be(:project_owner) { create(:user, owner_of: project) }
    let_it_be(:forked_project_owner) { project_owner }
    let_it_be(:project_developer) { create(:user, developer_of: project) }
    let_it_be(:owner_of_project_in_same_namespace) { create(:user, owner_of: project_in_same_namespace) }

    let_it_be(:forked_project) { fork_project(project, project_owner, repository: true) }

    let_it_be_with_refind(:project_secrets_manager) { create(:project_secrets_manager, project: project) }
    let_it_be_with_refind(:secrets_manager_of_project_in_same_namespace) do
      create(:project_secrets_manager, project: project_in_same_namespace)
    end

    let_it_be_with_refind(:secrets_manager_of_forked_project) do
      create(:project_secrets_manager, project: forked_project)
    end

    let_it_be(:merge_request) do
      create(:merge_request, source_project: forked_project, source_branch: 'feature', target_project: project,
        target_branch: 'master')
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

    let(:forked_project_build_running_in_original_project) do
      create(:ee_ci_build, pipeline: merge_request_pipeline_from_forked_project_running_in_original_project,
        user: project_owner)
    end

    let(:forked_project_build_running_in_forked_project) do
      create(:ee_ci_build, pipeline: merge_request_pipeline_from_forked_project_running_in_forked_project,
        user: project_owner)
    end

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
