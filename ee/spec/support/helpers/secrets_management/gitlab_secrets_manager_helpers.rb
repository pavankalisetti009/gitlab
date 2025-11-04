# frozen_string_literal: true

module SecretsManagement
  module GitlabSecretsManagerHelpers
    def clean_all_kv_secrets_engines
      client = secrets_manager_client
      client.each_secrets_engine do |path, info|
        next unless info["type"] == "kv"

        client.disable_secrets_engine(path)
      end
    end

    def clean_all_pipeline_jwt_engines
      client = secrets_manager_client
      client.each_auth_engine do |path, info|
        next unless info["type"] == "jwt"
        next unless path.include? "pipeline_jwt"

        client.disable_auth_engine(path)
      end
    end

    def clean_all_user_jwt_engines
      client = secrets_manager_client
      client.each_auth_engine do |path, info|
        next unless info["type"] == "jwt"
        next unless path.include? "user_jwt"

        client.disable_auth_engine(path)
      end
    end

    def clean_all_policies
      client = secrets_manager_client
      client.each_acl_policy do |name|
        next unless name.start_with? "project_"

        client.delete_policy(name)
      end
    end

    def clean_all_namespaces
      client = secrets_manager_client
      client.each_namespace do |path|
        next unless path.starts_with?("user_") || path.starts_with?("group_")

        ns_client = client

        path = path.delete_suffix('/')
        if path.include? '/'
          parent, _, child = path.rpartition('/')
          ns_client = client.with_namespace(parent)
          path = child
        end

        10.times do |n|
          result = ns_client.disable_namespace(path)
          next unless result.key?("data") && !result["data"].nil? &&
            result["data"].key?("status") && !result["data"]["status"].nil? &&
            result["data"]["status"] == "in-progress"

          sleep 0.1 * n
        end
      end
    end

    def provision_project_secrets_manager(secrets_manager, user)
      ProjectSecretsManagers::ProvisionService.new(secrets_manager, user).execute
    end

    def expect_kv_secret_engine_to_be_mounted(namespace_path, path)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_secrets_engine_configuration(path) }.not_to raise_error
    end

    def expect_kv_secret_engine_not_to_be_mounted(namespace_path, path)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_secrets_engine_configuration(path) }
        .to raise_error(SecretsManagerClient::ApiError)
    end

    def expect_kv_secret_to_have_value(namespace_path, mount_path, path, value)
      client = secrets_manager_client.with_namespace(namespace_path)
      stored_data = client.read_kv_secret_value(mount_path, path)
      expect(stored_data).to eq(value)
    end

    def expect_kv_secret_to_have_custom_metadata(namespace_path, mount_path, path, metadata)
      client = secrets_manager_client.with_namespace(namespace_path)
      stored_data = client.read_secret_metadata(mount_path, path)
      expect(stored_data["custom_metadata"]).to include(metadata)
    end

    def expect_kv_secret_not_to_have_custom_metadata(namespace_path, mount_path, path, metadata)
      client = secrets_manager_client.with_namespace(namespace_path)
      stored_data = client.read_secret_metadata(mount_path, path)
      expect(stored_data["custom_metadata"]).not_to include(metadata)
    end

    def expect_kv_secret_to_have_metadata_version(namespace_path, mount_path, path, version)
      client = secrets_manager_client.with_namespace(namespace_path)
      stored_data = client.read_secret_metadata(mount_path, path)
      expect(stored_data["current_metadata_version"]).to eq(version)
    end

    def expect_project_secret_not_to_exist(project, name, user = nil)
      user ||= create(:user)
      result = ProjectSecrets::ReadService.new(project, user).execute(name)
      expect(result).to be_error
      expect(result.message).to eq('Project secret does not exist.')
    end

    def expect_kv_secret_not_to_exist(namespace_path, mount_path, path)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect(client.read_secret_metadata(mount_path, path)).to be_nil
      expect(client.read_kv_secret_value(mount_path, path)).to be_nil
    end

    def expect_jwt_auth_engine_to_be_mounted(namespace_path, path)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_auth_engine_configuration(path) }.not_to raise_error
    end

    def expect_jwt_auth_engine_not_to_be_mounted(namespace_path, path)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_auth_engine_configuration(path) }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
    end

    def secrets_manager_client
      jwt = TestJwt.new.encoded

      TestClient.new(jwt: jwt)
    end

    def create_project_secret(
      user:, project:, name:, branch:, environment:, value:, description: nil,
      rotation_interval_days: nil)
      result = ProjectSecrets::CreateService.new(project, user).execute(
        name: name,
        value: value,
        description: description,
        branch: branch,
        environment: environment,
        rotation_interval_days: rotation_interval_days
      )

      project_secret = result.payload[:project_secret]

      if project_secret.errors.any?
        raise "project secret creation failed with errors: #{project_secret.errors.full_messages.to_sentence}"
      end

      project_secret
    end

    def update_secret_permission(user:, project:, principal:, permissions:, expired_at: nil)
      result = SecretsManagement::Permissions::UpdateService.new(project, user).execute(
        principal_id: principal[:id],
        principal_type: principal[:type],
        permissions: permissions,
        expired_at: expired_at
      )

      secret_permission = result.payload[:secret_permission]

      if secret_permission.errors.any?
        raise "secret permission creation failed with errors: #{secret_permission.errors.full_messages.to_sentence}"
      end

      secret_permission
    end

    def secret_rotation_info_for_project_secret(project, name, version = 1)
      SecretRotationInfo.for_project_secret(project, name, version)
    end

    def update_kv_secret_with_metadata(mount_path, secret_path, value, custom_metadata)
      client.update_kv_secret(
        mount_path,
        secret_path,
        value
      )

      client.update_kv_secret_metadata(
        mount_path,
        secret_path,
        custom_metadata
      )
    end

    def expect_jwt_role_to_exist(namespace_path, mount_path, role_name)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_jwt_role(mount_path, role_name) }.not_to raise_error
    end

    def expect_jwt_role_not_to_exist(namespace_path, mount_path, role_name)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_jwt_role(mount_path, role_name) }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
    end

    def expect_jwt_cel_role_to_exist(namespace_path, mount_path, role_name)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_jwt_cel_role(mount_path, role_name) }.not_to raise_error
    end

    def expect_jwt_cel_role_not_to_exist(namespace_path, mount_path, role_name)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_jwt_cel_role(mount_path, role_name) }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
    end

    def expect_policy_to_exist(namespace_path, policy_name)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect(client.get_raw_policy(policy_name)).not_to be_nil,
        "Expected policy '#{policy_name}' to exist, but it was not found"
    end

    def expect_policy_not_to_exist(namespace_path, path)
      secrets_manager_client.with_namespace(namespace_path)
      expect(secrets_manager_client.get_raw_policy(path)).to be_nil
    end

    def expect_project_to_have_no_policies(project_namespace)
      if project_namespace.empty?
        project_policies = find_project_policies(project_namespace)
        expect(project_policies).to be_empty,
          "Expected project #{project.id} to have no policies, but found: #{project_policies.join(', ')}"
      else
        expect do
          project_policies = find_project_policies(project_namespace)
        end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
      end
    end

    def find_project_policies(project_namespace)
      project_policies = []

      client = secrets_manager_client.with_namespace(project_namespace)
      client.each_acl_policy do |policy_name|
        project_policies << policy_name unless policy_name == "default"
      end

      project_policies
    end

    def expect_legacy_project_to_have_no_policies(project)
      project_policies = secrets_manager_client.list_project_policies(project_id: project.id)
      expect(project_policies).to be_empty,
        "Expected project #{project.id} to have no legacy policies, but found: #{project_policies.join(', ')}"
    end

    def cancel_exclusive_project_secret_operation_lease(project)
      lease_key = "project_secret_operation:project_#{project.id}"
      uuid = Gitlab::ExclusiveLease.get_uuid(lease_key)
      Gitlab::ExclusiveLease.cancel(lease_key, uuid)
    end
  end
end
