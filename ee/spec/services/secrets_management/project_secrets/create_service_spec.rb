# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecrets::CreateService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user, owner_of: project) }

  let(:service) { described_class.new(project, user) }
  let(:name) { 'TEST_SECRET' }
  let(:description) { 'test description' }
  let(:value) { 'the-secret-value' }
  let(:branch) { 'main' }
  let(:environment) { 'prod' }
  let(:rotation_interval_days) { 30 }

  subject(:result) do
    service.execute(
      name: name,
      description: description,
      value: value,
      branch: branch,
      environment: environment,
      rotation_interval_days: rotation_interval_days
    )
  end

  describe '#execute', :aggregate_failures, :freeze_time do
    context 'when the project secrets manager is active' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }

      before do
        provision_project_secrets_manager(secrets_manager, user)
      end

      it 'creates a project secret' do
        frozen_time = Time.current.utc.iso8601

        secret = result.payload[:project_secret]
        expect(secret).to be_present
        expect(secret.name).to eq(name)
        expect(secret.description).to eq(description)
        expect(secret.project).to eq(project)
        expect(secret.metadata_version).to eq(2)

        expect_kv_secret_to_have_value(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          value
        )

        rotation_info = secret_rotation_info_for_project_secret(project, secret.name)
        expect(rotation_info).not_to be_nil
        expect(rotation_info.rotation_interval_days).to eq(rotation_interval_days)
        expect(rotation_info.secret_metadata_version).to eq(1)
        expect(rotation_info.next_reminder_at).to be_present
        expect(rotation_info.last_reminder_at).to be_nil

        expect(secret.rotation_info).to eq(rotation_info)

        expect_kv_secret_to_have_metadata_version(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          rotation_info.secret_metadata_version + 1
        )

        expect_kv_secret_to_have_custom_metadata(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          "description" => description,
          "environment" => environment,
          "branch" => branch,
          "secret_rotation_info_id" => rotation_info.id.to_s,
          "create_completed_at" => frozen_time
        )

        # Validate correct policy has path.
        expected_policy_name = project.secrets_manager.ci_policy_name_combined(environment, branch)

        client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
        actual_policy = client.get_policy(expected_policy_name)
        expect(actual_policy).not_to be_nil

        expected_path = project.secrets_manager.ci_full_path(name)
        expect(actual_policy.paths).to include(expected_path)
        expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

        expected_path = project.secrets_manager.ci_metadata_full_path(name)
        expect(actual_policy.paths).to include(expected_path)
        expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))
      end

      context 'when rotation_interval_days is not given' do
        let(:rotation_interval_days) { nil }

        it 'does not create a rotation info record' do
          expect(result).to be_success

          secret = result.payload[:project_secret]
          rotation_info = secret_rotation_info_for_project_secret(project, secret.name)
          expect(rotation_info).to be_nil
          expect(secret.rotation_info).to be_nil
        end
      end

      context 'when using any environment' do
        let(:environment) { '*' }

        it 'create the correct policy and custom metadata' do
          expect(result).to be_success

          # Validate correct policy has path.
          expected_policy_name = project.secrets_manager.ci_policy_name_branch(branch)

          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          actual_policy = client.get_policy(expected_policy_name)
          expect(actual_policy).not_to be_nil

          expected_path = project.secrets_manager.ci_full_path(name)
          expect(actual_policy.paths).to include(expected_path)
          expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

          expected_path = project.secrets_manager.ci_metadata_full_path(name)
          expect(actual_policy.paths).to include(expected_path)
          expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "environment" => environment
          )
        end
      end

      context 'when using any branch' do
        let(:branch) { '*' }

        it 'create the correct policy and custom metadata' do
          expect(result).to be_success

          # Validate correct policy has path.
          expected_policy_name = project.secrets_manager.ci_policy_name_env(environment)

          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          actual_policy = client.get_policy(expected_policy_name)
          expect(actual_policy).not_to be_nil

          expected_path = project.secrets_manager.ci_full_path(name)
          expect(actual_policy.paths).to include(expected_path)
          expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

          expected_path = project.secrets_manager.ci_metadata_full_path(name)
          expect(actual_policy.paths).to include(expected_path)
          expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "branch" => branch
          )
        end

        context 'and any environmnet' do
          let(:environment) { '*' }

          it 'create the correct policy and custom metadata' do
            expect(result).to be_success

            # Validate correct policy has path.
            expected_policy_name = project.secrets_manager.ci_policy_name_global

            client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
            actual_policy = client.get_policy(expected_policy_name)
            expect(actual_policy).not_to be_nil

            expected_path = project.secrets_manager.ci_full_path(name)
            expect(actual_policy.paths).to include(expected_path)
            expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

            expected_path = project.secrets_manager.ci_metadata_full_path(name)
            expect(actual_policy.paths).to include(expected_path)
            expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

            expect_kv_secret_to_have_custom_metadata(
              project.secrets_manager.full_project_namespace_path,
              project.secrets_manager.ci_secrets_mount_path,
              secrets_manager.ci_data_path(name),
              "environment" => environment,
              "branch" => branch
            )
          end
        end

        context 'when not providing an environment' do
          let(:environment) { '' }

          it 'fails' do
            expect(result).to be_error
            expect(result.message).to eq('Environment can\'t be blank')
          end
        end

        context 'when not providing a branch' do
          let(:branch) { '' }

          it 'fails' do
            expect(result).to be_error
            expect(result.message).to eq('Branch can\'t be blank')
          end
        end
      end

      shared_examples_for 'rejecting secrets that exist' do
        it 'fails' do
          expect(result).to be_error
          expect(result.message).to eq('Project secret already exists.')
        end
      end

      context 'when the secret is created but initial metadata update fail' do
        let(:existing_rotation_interval_days) { nil }

        before do
          allow_next_instance_of(described_class) do |svc|
            allow(svc).to receive(:user_client).and_wrap_original do |orig|
              client = orig.call

              failed_once = false

              allow(client).to receive(:update_kv_secret_metadata).and_wrap_original do |orig_ud, *args, **kwargs|
                if !failed_once && kwargs[:metadata_cas] == 0
                  failed_once = true
                  raise SecretsManagement::SecretsManagerClient::ApiError, 'metadata write failed'
                end

                orig_ud.call(*args, **kwargs)
              end

              client
            end
          end

          begin
            described_class.new(project, user).execute(
              name: name,
              value: value,
              environment: environment,
              branch: branch,
              rotation_interval_days: existing_rotation_interval_days
            )
          rescue SecretsManagement::SecretsManagerClient::ApiError => e
            raise unless e.message == 'metadata write failed'
          end
        end

        it_behaves_like 'rejecting secrets that exist'
      end

      context 'when the secret already exists' do
        before do
          described_class.new(project, user)
            .execute(
              name: name,
              value: value,
              environment: environment,
              branch: branch,
              rotation_interval_days: existing_rotation_interval_days
            )
        end

        context 'and the existing secret was not configured to rotate' do
          let(:existing_rotation_interval_days) { nil }

          it_behaves_like 'rejecting secrets that exist'

          it 'does not create a secret rotation info record' do
            expect(result).to be_error
            rotation_info = secret_rotation_info_for_project_secret(project, name)
            expect(rotation_info).to be_nil
          end
        end

        context 'and the existing secret was configured to rotate' do
          let(:existing_rotation_interval_days) { 60 }

          context 'and the new request did not have rotation for the secret' do
            let(:rotation_interval_days) { nil }

            it_behaves_like 'rejecting secrets that exist'

            it 'does not remove the existing secret rotation info record' do
              expect(result).to be_error
              rotation_info = secret_rotation_info_for_project_secret(project, name)
              expect(rotation_info).not_to be_nil
              expect(rotation_info.reload.rotation_interval_days).to eq(existing_rotation_interval_days)
              expect(rotation_info.secret_metadata_version).to eq(1)
            end
          end

          context 'and the new request have rotation for the secret' do
            it_behaves_like 'rejecting secrets that exist'

            it 'does not update the existing secret rotation info record' do
              expect(result).to be_error
              rotation_info = secret_rotation_info_for_project_secret(project, name)
              expect(rotation_info).not_to be_nil
              expect(rotation_info.reload.rotation_interval_days).to eq(existing_rotation_interval_days)
              expect(rotation_info.secret_metadata_version).to eq(1)
            end
          end
        end
      end

      context 'when retrying to create a secret that previously partially failed' do
        context 'and it failed to create the secret in openbao after rotation info record was created successfully' do
          let(:existing_rotation_interval_days) { 30 }
          let(:existing_rotation_info) { secret_rotation_info_for_project_secret(project, name) }

          before do
            webmock_enable!(allow_localhost: false)

            secret_metadata_path = [
              SecretsManagement::SecretsManagerClient.configuration.host,
              SecretsManagement::SecretsManagerClient.configuration.base_path,
              secrets_manager.full_project_namespace_path,
              secrets_manager.ci_secrets_mount_path,
              'metadata',
              secrets_manager.ci_data_path(name)
            ].join('/')

            secret_create_path = [
              SecretsManagement::SecretsManagerClient.configuration.host,
              SecretsManagement::SecretsManagerClient.configuration.base_path,
              secrets_manager.full_project_namespace_path,
              secrets_manager.ci_secrets_mount_path,
              'data',
              secrets_manager.ci_data_path(name)
            ].join('/')

            # Mock the openbao read secret metadata API call to return not found so that it proceeds with creation
            stub_request(:get, secret_metadata_path).to_return(status: 404, body: '')

            # Mock the openbao create secret API call to fail
            stub_request(:post, secret_create_path).to_timeout

            # rubocop:disable RSpec/ExpectInHook -- Just to ensure our setup is correct
            expect do
              # This first execution will fail
              described_class.new(project, user)
                .execute(
                  name: name,
                  value: value,
                  environment: environment,
                  branch: branch,
                  rotation_interval_days: existing_rotation_interval_days
                )
            end.to raise_error(SecretsManagement::SecretsManagerClient::ConnectionError)

            webmock_enable!(allow_localhost: true)
            WebMock.reset!

            # Before we retry, let's validate the first request results
            # The secret rotation record should exist
            expect(existing_rotation_info.rotation_interval_days).to eq(existing_rotation_interval_days)
            expect(existing_rotation_info.secret_metadata_version).to eq(1)

            # The secret should not exist in openbao
            expect_kv_secret_not_to_exist(
              project.secrets_manager.full_project_namespace_path,
              project.secrets_manager.ci_secrets_mount_path,
              secrets_manager.ci_data_path(name)
            )
            # rubocop:enable RSpec/ExpectInHook
          end

          context 'and rotation_interval_days value was changed upon retry' do
            let(:rotation_interval_days) { 60 }

            it 'updates the rotation info and creates the secret in openbao' do
              # Now, retry
              # Verify that the secret rotation interval days was updated
              expect { result }.to change {
                existing_rotation_info.reload.rotation_interval_days
              }.to rotation_interval_days
              expect(result).to be_success
              expect(existing_rotation_info.secret_metadata_version).to eq(1)
              secret = result.payload[:project_secret]
              expect(secret.rotation_info).to eq(existing_rotation_info)

              # Verify that the secret now exists in openbao
              expect_kv_secret_to_have_value(
                project.secrets_manager.full_project_namespace_path,
                project.secrets_manager.ci_secrets_mount_path,
                secrets_manager.ci_data_path(name),
                value
              )

              expect_kv_secret_to_have_metadata_version(
                project.secrets_manager.full_project_namespace_path,
                project.secrets_manager.ci_secrets_mount_path,
                secrets_manager.ci_data_path(name),
                existing_rotation_info.secret_metadata_version + 1
              )

              expect_kv_secret_to_have_custom_metadata(
                project.secrets_manager.full_project_namespace_path,
                project.secrets_manager.ci_secrets_mount_path,
                secrets_manager.ci_data_path(name),
                "secret_rotation_info_id" => existing_rotation_info.id.to_s
              )
            end
          end

          context 'and rotation_interval_days was removed upon retry' do
            let(:rotation_interval_days) { nil }

            it 'ignores the existing rotation info record and creates the secret in openbao' do
              # Now, retry
              # Verify that the secret rotation record was not removed or updated.
              # We let the background job to eventually clean this orphaned record for consistency.
              expect { result }.not_to change {
                existing_rotation_info.reload.rotation_interval_days
              }
              expect(result).to be_success
              secret = result.payload[:project_secret]
              expect(secret.rotation_info).to be_nil

              # Verify that the secret now exists in openbao
              expect_kv_secret_to_have_value(
                project.secrets_manager.full_project_namespace_path,
                project.secrets_manager.ci_secrets_mount_path,
                secrets_manager.ci_data_path(name),
                value
              )

              expect_kv_secret_to_have_metadata_version(
                project.secrets_manager.full_project_namespace_path,
                project.secrets_manager.ci_secrets_mount_path,
                secrets_manager.ci_data_path(name),
                2
              )

              expect_kv_secret_not_to_have_custom_metadata(
                project.secrets_manager.full_project_namespace_path,
                project.secrets_manager.ci_secrets_mount_path,
                secrets_manager.ci_data_path(name),
                "secret_rotation_info_id" => existing_rotation_info.id.to_s
              )
            end
          end
        end

        shared_examples_for 'handling invalid input' do
          it 'fails and does not create anything' do
            expect(result).to be_error

            expect(SecretsManagement::SecretRotationInfo.count).to be_zero

            expect_kv_secret_not_to_exist(
              project.secrets_manager.full_project_namespace_path,
              project.secrets_manager.ci_secrets_mount_path,
              secrets_manager.ci_data_path(name)
            )
          end
        end

        context 'when the secret rotation info is invalid' do
          let(:rotation_interval_days) { 1 }

          it_behaves_like 'handling invalid input'
        end

        context 'when the secret info is invalid' do
          let(:name) { "inv@lid-name!" }

          it_behaves_like 'handling invalid input'
        end
      end
    end

    context 'when user is a developer and no permissions' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }
      let(:user) { create(:user, developer_of: project) }

      subject(:result) do
        service.execute(name: name, description: description, value: value, branch: branch, environment: environment)
      end

      it 'returns an error' do
        provision_project_secrets_manager(secrets_manager, user)
        expect { result }
          .to raise_error(
            SecretsManagement::SecretsManagerClient::ApiError,
            "1 error occurred:\n\t* permission denied\n\n"
          )
      end
    end

    context 'when user role - developer has proper permissions' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }
      let(:user) { create(:user, developer_of: project) }

      subject(:result) do
        service.execute(name: name, description: description, value: value, branch: branch, environment: environment)
      end

      before do
        provision_project_secrets_manager(secrets_manager, user)
        update_secret_permission(
          user: user, project: project, permissions: %w[create read update], principal: {
            id: Gitlab::Access.sym_options[:developer], type: 'Role'
          }
        )
      end

      it 'returns success' do
        expect(result).to be_success
        expect(result.payload[:project_secret]).to be_present
      end
    end

    context 'when user has proper permissions' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }
      let(:user) { create(:user, developer_of: project) }
      let(:expired_at) { nil }

      subject(:result) do
        service.execute(name: name, description: description, value: value, branch: branch, environment: environment)
      end

      def provision_and_update_secret_permission
        provision_project_secrets_manager(secrets_manager, user)
        update_secret_permission(
          user: user, project: project, permissions: %w[create read update], principal: {
            id: user.id, type: 'User'
          }, expired_at: expired_at
        )
      end

      context 'when expired_at is nil' do
        it 'returns success' do
          permission = provision_and_update_secret_permission

          expect(result).to be_success
          expect(result.payload[:project_secret]).to be_present
          expect(permission.expired_at).to be_nil
        end
      end

      context 'when expired_at is in the future' do
        let(:expired_at) { 2.days.from_now }

        it 'returns success' do
          permission = provision_and_update_secret_permission

          expect(result).to be_success
          expect(result.payload[:project_secret]).to be_present
          expect(permission.expired_at).to eq(expired_at.to_s)
        end
      end
    end

    context 'when expired_at is in the past' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }
      let(:user) { create(:user, developer_of: project) }
      let(:expired_at) { 2.days.ago }

      it 'raises an error' do
        provision_project_secrets_manager(secrets_manager, user)

        expect do
          update_secret_permission(
            user: user, project: project, permissions: %w[create read update], principal: {
              id: user.id, type: 'User'
            }, expired_at: expired_at
          )
        end.to raise_error(RuntimeError, /Expired at must be in the future/)
      end
    end

    context 'when the project secrets manager is not active' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }

      it 'fails' do
        expect(result).to be_error
        expect(result.message).to eq('Project secrets manager is not active.')
      end
    end

    context 'when the project has not enabled secrets manager at all' do
      it 'fails' do
        expect(result).to be_error
        expect(result.message).to eq('Project secrets manager is not active.')
      end
    end
  end
end
