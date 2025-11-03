# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecrets::UpdateService, :gitlab_secrets_manager, feature_category: :secrets_management do
  include SecretsManagement::GitlabSecretsManagerHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let_it_be(:user) { create(:user, owner_of: project) }

  let(:service) { described_class.new(project, user) }
  let(:name) { 'TEST_SECRET' }
  let(:original_description) { 'test description' }
  let(:original_value) { 'the-secret-value' }
  let(:original_branch) { 'main' }
  let(:original_environment) { 'prod' }
  let(:original_rotation_interval_days) { nil }

  let(:new_description) { 'updated description' }
  let(:new_value) { 'updated-secret-value' }
  let(:new_branch) { 'feature' }
  let(:new_environment) { 'staging' }
  let(:new_rotation_interval_days) { 30 }

  let(:description) { nil }
  let(:value) { nil }
  let(:branch) { nil }
  let(:environment) { nil }
  let(:rotation_interval_days) { nil }
  let(:initial_metadata_version) { 2 }
  let(:metadata_cas) { initial_metadata_version }
  let(:expected_version_after_update) { initial_metadata_version + 1 }
  let(:version_on_create) { 1 }

  describe '#execute', :aggregate_failures, :freeze_time do
    context 'when the project secrets manager is active' do
      subject(:result) do
        service.execute(
          name: name,
          description: description,
          value: value,
          branch: branch,
          environment: environment,
          rotation_interval_days: rotation_interval_days,
          metadata_cas: metadata_cas
        )
      end

      before do
        provision_project_secrets_manager(secrets_manager, user)

        # Create a secret to update
        create_project_secret(
          user: user,
          project: project,
          name: name,
          value: original_value,
          branch: original_branch,
          environment: original_environment,
          description: original_description,
          rotation_interval_days: original_rotation_interval_days
        )
      end

      shared_examples_for 'handling empty rotation_interval_days parameter' do
        context 'when original secret had rotation configured' do
          let(:original_rotation_interval_days) { 60 }

          it 'unassigns the old rotation info record from the secret' do
            expect(result).to be_success

            secret = result.payload[:project_secret]
            expect(secret.rotation_info).to be_nil

            # Rotation info with the previous version still exists (will be cleaned by background job)
            original_rotation_info = secret_rotation_info_for_project_secret(project, name, 1)
            expect(original_rotation_info).not_to be_nil

            # No new rotation record is created
            rotation_info = secret_rotation_info_for_project_secret(project, name, 2)
            expect(rotation_info).to be_nil

            # Rotation ID is removed from metadata
            expect_kv_secret_not_to_have_custom_metadata(
              project.secrets_manager.full_project_namespace_path,
              project.secrets_manager.ci_secrets_mount_path,
              secrets_manager.ci_data_path(name),
              "secret_rotation_info_id"
            )
          end
        end
      end

      context 'when updating description only' do
        let(:description) { new_description }

        it 'updates the description only' do
          expect(result).to be_success
          expect(result.payload[:project_secret].description).to eq(new_description)
          expect(result.payload[:project_secret].metadata_version).to eq(initial_metadata_version + 1)

          # Verify metadata was updated
          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "description" => new_description
          )

          # Verify value is unchanged
          expect_kv_secret_to_have_value(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            original_value
          )

          # Verify policies are unchanged
          client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
          policy_name = project.secrets_manager.ci_policy_name(original_environment, original_branch)
          policy = client.get_policy(policy_name)
          expect(policy.paths).to include(project.secrets_manager.ci_full_path(name))
        end

        it_behaves_like 'handling empty rotation_interval_days parameter'
      end

      context 'when updating value only' do
        let(:value) { new_value }

        it 'updates the value' do
          expect(result).to be_success
          expect(result.payload[:project_secret].metadata_version).to eq(expected_version_after_update)

          # Verify the value was updated
          expect_kv_secret_to_have_value(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            new_value
          )

          # Verify metadata is unchanged except version
          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "description" => original_description,
            "environment" => original_environment,
            "branch" => original_branch
          )
        end

        it_behaves_like 'handling empty rotation_interval_days parameter'
      end

      context 'when adding rotation to a secret without existing rotation' do
        let(:rotation_interval_days) { new_rotation_interval_days }

        it 'creates a new rotation info record' do
          expect(result).to be_success

          secret = result.payload[:project_secret]
          new_version = initial_metadata_version + 1
          rotation_info = secret_rotation_info_for_project_secret(project, name, new_version)

          expect(rotation_info).not_to be_nil
          expect(rotation_info.rotation_interval_days).to eq(new_rotation_interval_days)
          expect(rotation_info.next_reminder_at).to be_present
          expect(rotation_info.last_reminder_at).to be_nil
          expect(secret.rotation_info).to eq(rotation_info)

          expect_kv_secret_to_have_metadata_version(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            expected_version_after_update + 1
          )

          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "secret_rotation_info_id" => rotation_info.id.to_s
          )
        end
      end

      context 'when updating rotation interval of existing rotation' do
        let(:original_rotation_interval_days) { 60 }
        let(:rotation_interval_days) { new_rotation_interval_days }

        it 'creates a new rotation info record with new interval' do
          expect(result).to be_success

          secret = result.payload[:project_secret]

          # Old rotation info is left untouched and will be cleaned up by the background job
          old_rotation_info = secret_rotation_info_for_project_secret(project, name, version_on_create)
          expect(old_rotation_info).not_to be_nil
          expect(old_rotation_info.rotation_interval_days).to eq(original_rotation_interval_days)

          # New rotation info should be created with new version
          new_version = metadata_cas + 1
          new_rotation_info = secret_rotation_info_for_project_secret(project, name, new_version)
          expect(new_rotation_info).not_to be_nil
          expect(new_rotation_info.id).not_to eq(old_rotation_info.id)
          expect(new_rotation_info.rotation_interval_days).to eq(new_rotation_interval_days)
          expect(new_rotation_info.next_reminder_at).to be_present
          expect(new_rotation_info.last_reminder_at).to be_nil
          expect(secret.rotation_info).to eq(new_rotation_info)

          expect_kv_secret_to_have_metadata_version(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            new_version + 1
          )

          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "secret_rotation_info_id" => new_rotation_info.id.to_s
          )
        end
      end

      context 'when explicitly preserving rotation with same interval' do
        let(:original_rotation_interval_days) { new_rotation_interval_days }
        let(:rotation_interval_days) { new_rotation_interval_days }

        it 'creates a new rotation info record with the same interval' do
          expect(result).to be_success

          secret = result.payload[:project_secret]

          # Old rotation info is left untouched and will be cleaned up by the background job
          old_rotation_info = secret_rotation_info_for_project_secret(project, name, version_on_create)
          expect(old_rotation_info).not_to be_nil
          expect(old_rotation_info.rotation_interval_days).to eq(original_rotation_interval_days)

          # New rotation info should be created with new version
          new_version = metadata_cas + 1
          new_rotation_info = secret_rotation_info_for_project_secret(project, name, new_version)
          expect(new_rotation_info).not_to be_nil
          expect(new_rotation_info.id).not_to eq(old_rotation_info.id)
          expect(new_rotation_info.rotation_interval_days).to eq(new_rotation_interval_days)
          expect(new_rotation_info.next_reminder_at).to be_present
          expect(new_rotation_info.last_reminder_at).to be_nil
          expect(secret.rotation_info).to eq(new_rotation_info)

          expect_kv_secret_to_have_metadata_version(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            new_version + 1
          )

          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "secret_rotation_info_id" => new_rotation_info.id.to_s
          )
        end
      end

      context 'when secrets creation is in progress', :freeze_time do
        let(:description) { new_description }
        let(:mount) { project.secrets_manager.ci_secrets_mount_path }

        it 'fails to update' do
          client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)

          client.update_kv_secret_metadata(
            mount,
            project.secrets_manager.ci_data_path(name),
            {
              description: 'Second secret',
              environment: 'staging',
              branch: 'staging'
            },
            metadata_cas: 2
          )

          expect(result).not_to be_success
          expect(result.message).to eq("Secret create in progress.")
        end
      end

      context 'when metadata timing fields are written', :freeze_time do
        let(:description) { new_description }

        it 'sets update_started_at and update_completed_at and bumps metadata twice' do
          frozen_iso = Time.current.utc.iso8601

          expect(result).to be_success

          expect_kv_secret_to_have_metadata_version(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            metadata_cas + 2
          )

          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "update_started_at" => frozen_iso,
            "update_completed_at" => frozen_iso
          )
        end

        context 'when metadata_cas is not given' do
          let(:description) { new_description }
          let(:metadata_cas) { nil }

          it 'sets both timestamps and uses previous version + 1 then + 2' do
            frozen_iso = Time.current.utc.iso8601
            expect(result).to be_success

            expect_kv_secret_to_have_metadata_version(
              project.secrets_manager.full_project_namespace_path,
              project.secrets_manager.ci_secrets_mount_path,
              secrets_manager.ci_data_path(name),
              initial_metadata_version + 2
            )

            expect_kv_secret_to_have_custom_metadata(
              project.secrets_manager.full_project_namespace_path,
              project.secrets_manager.ci_secrets_mount_path,
              secrets_manager.ci_data_path(name),
              "update_started_at" => frozen_iso,
              "update_completed_at" => frozen_iso
            )

            expect(result.payload[:project_secret].metadata_version).to be_nil
          end
        end
      end

      context 'when updating environment' do
        let(:environment) { new_environment }

        it 'updates the environment and policies' do
          expect(result).to be_success
          expect(result.payload[:project_secret].environment).to eq(new_environment)
          expect(result.payload[:project_secret].metadata_version).to eq(3)

          # Verify metadata was updated
          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "environment" => new_environment
          )

          # Verify old policy no longer contains the secret
          client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
          old_policy_name = project.secrets_manager.ci_policy_name(original_environment, original_branch)
          old_policy = client.get_policy(old_policy_name)

          expect(old_policy.paths).not_to include(project.secrets_manager.ci_full_path(name))

          # Verify new policy contains the secret
          new_policy_name = project.secrets_manager.ci_policy_name(new_environment, original_branch)
          new_policy = client.get_policy(new_policy_name)

          expect(new_policy.paths).to include(project.secrets_manager.ci_full_path(name))
        end
      end

      context 'when the original policy has no other secrets' do
        let(:environment) { new_environment }

        it 'removes the old policy entirely' do
          expect(result).to be_success

          # Verify the old policy has been completely deleted or is empty
          secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
          old_policy_name = project.secrets_manager.ci_policy_name(original_environment, original_branch)
          old_policy = secrets_manager_client.get_policy(old_policy_name)

          expect(old_policy.paths).to be_empty
        end
      end

      context 'when updating branch' do
        let(:branch) { new_branch }

        it 'updates the branch and policies' do
          expect(result).to be_success
          expect(result.payload[:project_secret].branch).to eq(new_branch)
          expect(result.payload[:project_secret].metadata_version).to eq(3)

          # Verify metadata was updated
          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "branch" => new_branch
          )

          # Verify old policy no longer contains the secret
          client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
          old_policy_name = project.secrets_manager.ci_policy_name(original_environment, original_branch)
          old_policy = client.get_policy(old_policy_name)

          expect(old_policy.paths).not_to include(project.secrets_manager.ci_full_path(name))

          # Verify new policy contains the secret
          new_policy_name = project.secrets_manager.ci_policy_name(original_environment, new_branch)
          new_policy = client.get_policy(new_policy_name)

          expect(new_policy.paths).to include(project.secrets_manager.ci_full_path(name))
        end
      end

      context 'when updating everything' do
        let(:description) { new_description }
        let(:value) { new_value }
        let(:branch) { new_branch }
        let(:environment) { new_environment }
        let(:rotation_interval_days) { new_rotation_interval_days }

        context 'without original rotation' do
          it 'updates all fields, policies, and adds rotation' do
            expect(result).to be_success

            secret = result.payload[:project_secret]
            expect(secret.description).to eq(new_description)
            expect(secret.branch).to eq(new_branch)
            expect(secret.environment).to eq(new_environment)
            expect(secret.metadata_version).to eq(3)

            # Verify rotation was added
            new_version = metadata_cas + 1
            rotation_info = secret_rotation_info_for_project_secret(project, name, new_version)
            expect(rotation_info).not_to be_nil
            expect(rotation_info.rotation_interval_days).to eq(new_rotation_interval_days)
            expect(secret.rotation_info).to eq(rotation_info)

            # Verify value was updated
            expect_kv_secret_to_have_value(
              project.secrets_manager.full_project_namespace_path,
              project.secrets_manager.ci_secrets_mount_path,
              secrets_manager.ci_data_path(name),
              new_value
            )

            # Verify metadata was updated
            expect_kv_secret_to_have_metadata_version(
              project.secrets_manager.full_project_namespace_path,
              project.secrets_manager.ci_secrets_mount_path,
              secrets_manager.ci_data_path(name),
              new_version + 1
            )

            expect_kv_secret_to_have_custom_metadata(
              project.secrets_manager.full_project_namespace_path,
              project.secrets_manager.ci_secrets_mount_path,
              secrets_manager.ci_data_path(name),
              "description" => new_description,
              "environment" => new_environment,
              "branch" => new_branch,
              "secret_rotation_info_id" => rotation_info.id.to_s
            )

            # Verify old policy no longer contains the secret
            client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
            old_policy_name = project.secrets_manager.ci_policy_name(original_environment, original_branch)
            old_policy = client.get_policy(old_policy_name)

            expect(old_policy.paths).not_to include(project.secrets_manager.ci_full_path(name))

            # Verify new policy contains the secret
            new_policy_name = project.secrets_manager.ci_policy_name(new_environment, new_branch)
            new_policy = client.get_policy(new_policy_name)

            expect(new_policy.paths).to include(project.secrets_manager.ci_full_path(name))
          end
        end
      end

      context 'when updating environment or branch with wildcard patterns' do
        context 'when updating from non-wildcard to wildcard' do
          let(:branch) { 'feature/*' }
          let(:environment) { 'staging-*' }

          it 'updates environment and branch with wildcards and configures JWT role' do
            # Get glob policies for the wildcard patterns
            glob_policies = project.secrets_manager.ci_auth_glob_policies(environment, branch)

            # Run the update
            expect(result).to be_success

            # Check JWT role after update
            client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
            role_after = client.read_jwt_role(
              project.secrets_manager.ci_auth_mount,
              project.secrets_manager.ci_auth_role
            )

            # Verify glob policies are present after update
            expect(role_after["token_policies"] & glob_policies).to match_array(glob_policies)

            # Verify the secret is in the right policy
            new_policy_name = project.secrets_manager.ci_policy_name(environment, branch)
            new_policy = client.get_policy(new_policy_name)

            expect(new_policy.paths).to include(project.secrets_manager.ci_full_path(name))
          end
        end

        context 'when updating from wildcard to non-wildcard' do
          let(:original_branch) { 'feature/*' }
          let(:original_environment) { 'staging-*' }
          let(:environment) { 'production' }
          let(:branch) { 'master' }

          it 'removes wildcards from JWT role when not needed' do
            old_glob_policies = project.secrets_manager.ci_auth_glob_policies(original_environment, original_branch)

            # Check JWT role before update
            client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
            role_before = client.read_jwt_role(
              project.secrets_manager.ci_auth_mount,
              project.secrets_manager.ci_auth_role
            )

            # Verify glob policies exist before update
            expect(role_before["token_policies"] & old_glob_policies).to match_array(old_glob_policies)

            # Run the update to non-wildcards
            expect(result).to be_success

            # Check JWT role after update
            role_after = client.read_jwt_role(
              project.secrets_manager.ci_auth_mount,
              project.secrets_manager.ci_auth_role
            )

            # Verify glob policies were removed
            expect(role_after["token_policies"]).not_to include(*old_glob_policies)
          end

          context 'and other secrets are under the previous wildcards' do
            let(:second_secret_name) { 'SECOND_SECRET' }

            before do
              create_project_secret(
                user: user,
                project: project,
                name: second_secret_name,
                value: 'second-value',
                branch: original_branch,
                environment: original_environment,
                description: 'Second secret'
              )
            end

            it 'preserves the wildcards in JWT role needed by other secrets' do
              # Get glob policies for the second secret's wildcards
              second_glob_policies = project.secrets_manager.ci_auth_glob_policies('staging-*', 'feature/*')

              # Run the update (changing from non-wildcard to non-wildcard, but other secret has wildcards)
              expect(result).to be_success

              # Check JWT role after update
              client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
              role_after = client.read_jwt_role(
                project.secrets_manager.ci_auth_mount,
                project.secrets_manager.ci_auth_role
              )

              # Verify glob policies are still present for second secret
              second_glob_policies.each do |policy|
                expect(role_after["token_policies"]).to include(policy)
              end
            end
          end
        end
      end

      context 'when metadata_cas is not given' do
        let(:description) { new_description }
        let(:value) { new_value }
        let(:branch) { new_branch }
        let(:environment) { new_environment }
        let(:rotation_interval_days) { new_rotation_interval_days }
        let(:metadata_cas) { nil }

        it 'updates the secret without checking CAS' do
          expect(result).to be_success

          secret = result.payload[:project_secret]
          expect(secret.description).to eq(new_description)
          expect(secret.branch).to eq(new_branch)
          expect(secret.environment).to eq(new_environment)
          expect(secret.metadata_version).to be_nil

          # Verify rotation was added
          # When no CAS, we use previous_metadata_version + 1
          new_version = initial_metadata_version + 1
          rotation_info = secret_rotation_info_for_project_secret(project, name, new_version)
          expect(rotation_info).not_to be_nil
          expect(rotation_info.rotation_interval_days).to eq(new_rotation_interval_days)
          expect(secret.rotation_info).to eq(rotation_info)

          # Verify value was updated
          expect_kv_secret_to_have_value(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            new_value
          )

          # Verify metadata was updated
          expect_kv_secret_to_have_metadata_version(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            new_version + 1
          )

          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "description" => new_description,
            "environment" => new_environment,
            "branch" => new_branch,
            "secret_rotation_info_id" => rotation_info.id.to_s
          )
        end
      end

      context 'when given metadata_cas does not match the metadata version' do
        let(:description) { new_description }
        let(:value) { new_value }
        let(:branch) { new_branch }
        let(:environment) { new_environment }
        let(:metadata_cas) { 3 }

        it 'returns an error' do
          expect(result).not_to be_success
          expect(result.message).to eq("This secret has been modified recently. " \
            "Please refresh the page and try again.")

          # Verify value was not updated
          expect_kv_secret_to_have_value(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            original_value
          )

          # Verify metadata is unchanged
          expect_kv_secret_to_have_metadata_version(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            2
          )

          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "description" => original_description,
            "environment" => original_environment,
            "branch" => original_branch
          )
        end

        context 'and rotation interval is specified' do
          let(:rotation_interval_days) { new_rotation_interval_days }

          it 'creates a rotation info record but is unassigned' do
            expect(result).not_to be_success

            # Rotation info is created but will be cleaned up later by the background job
            rotation_info = secret_rotation_info_for_project_secret(project, name, metadata_cas + 1)
            expect(rotation_info).not_to be_nil

            expect_kv_secret_not_to_have_custom_metadata(
              project.secrets_manager.full_project_namespace_path,
              project.secrets_manager.ci_secrets_mount_path,
              secrets_manager.ci_data_path(name),
              "secret_rotation_info_id"
            )
          end
        end
      end

      context 'when the secret does not exist' do
        let(:nonexistent_name) { 'NONEXISTENT_SECRET' }

        subject(:nonexistent_result) do
          service.execute(name: nonexistent_name, metadata_cas: 1)
        end

        it 'returns an error' do
          expect(nonexistent_result).not_to be_success
          expect(nonexistent_result.message).to eq('Project secret does not exist.')
          expect(nonexistent_result.reason).to eq(:not_found)
        end
      end

      context 'with invalid inputs' do
        context 'when branch is empty' do
          let(:branch) { '' }

          it 'returns an error' do
            expect(result).not_to be_success
            expect(result.message).to eq("Branch can't be blank")
          end

          context 'with rotation interval specified' do
            let(:rotation_interval_days) { new_rotation_interval_days }

            it 'does not create rotation info when validation fails' do
              expect(result).not_to be_success

              # No new rotation info should be created
              rotation_info = secret_rotation_info_for_project_secret(project, name, metadata_cas + 1)
              expect(rotation_info).to be_nil
            end
          end
        end

        context 'when rotation interval is invalid' do
          let(:rotation_interval_days) { 1 } # Less than minimum

          it 'returns an error and does not update' do
            expect(result).not_to be_success
            expect(result.message).to include('Rotation configuration error')

            # Secret should remain unchanged
            expect_kv_secret_to_have_value(
              project.secrets_manager.full_project_namespace_path,
              project.secrets_manager.ci_secrets_mount_path,
              secrets_manager.ci_data_path(name),
              original_value
            )

            # No rotation info should be created
            rotation_info = secret_rotation_info_for_project_secret(project, name, metadata_cas + 1)
            expect(rotation_info).to be_nil
          end
        end
      end

      context 'when updating to share policy with another secret' do
        let(:second_secret_name) { 'SECOND_SECRET' }
        let(:environment) { 'shared-env' }  # Both secrets will share this environment
        let(:branch) { 'shared-branch' }    # Both secrets will share this branch

        before do
          # Create a second secret with the shared env/branch
          create_project_secret(
            user: user,
            project: project,
            name: second_secret_name,
            value: "second-value",
            branch: branch,
            environment: environment,
            description: "Second secret"
          )
        end

        it 'adds the secret to the shared policy' do
          expect(result).to be_success

          # Verify the shared policy has both secrets
          client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
          shared_policy_name = project.secrets_manager.ci_policy_name(environment, branch)
          shared_policy = client.get_policy(shared_policy_name)

          expect(shared_policy.paths).to include(project.secrets_manager.ci_full_path(name))
          expect(shared_policy.paths).to include(project.secrets_manager.ci_full_path(second_secret_name))
        end
      end
    end
  end

  context 'when user is a developer and no permissions' do
    let(:user) { create(:user, developer_of: project) }

    subject(:result) do
      service.execute(
        name: name,
        description: description,
        value: value,
        branch: branch,
        environment: environment,
        metadata_cas: metadata_cas
      )
    end

    it 'returns an error' do
      provision_project_secrets_manager(secrets_manager, user)

      expect { result }
      .to raise_error(SecretsManagement::SecretsManagerClient::ApiError,
        "1 error occurred:\n\t* permission denied\n\n")
    end
  end

  context 'when the project secrets manager is not active' do
    subject(:result) do
      service.execute(
        name: name,
        description: description,
        value: value,
        branch: branch,
        environment: environment,
        metadata_cas: metadata_cas
      )
    end

    it 'returns an error' do
      expect(result).to be_error
      expect(result.message).to eq('Project secrets manager is not active')
    end
  end
end
