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

    def clean_all_policies
      client = secrets_manager_client
      client.each_acl_policy do |name|
        next unless name.start_with? "project_"

        client.delete_policy(name)
      end
    end

    def provision_project_secrets_manager(secrets_manager)
      ProvisionProjectSecretsManagerService.new(secrets_manager).execute
    end

    def expect_kv_secret_engine_to_be_mounted(path)
      expect { secrets_manager_client.read_secrets_engine_configuration(path) }.not_to raise_error
    end

    def expect_kv_secret_to_have_value(mount_path, path, value)
      stored_data = secrets_manager_client.read_kv_secret_value(mount_path, path)
      expect(stored_data).to eq(value)
    end

    def expect_kv_secret_to_have_custom_metadata(mount_path, path, metadata)
      stored_data = secrets_manager_client.read_kv_secret_custom_metadata(mount_path, path)
      expect(stored_data).to include(metadata)
    end

    def secrets_manager_client
      TestClient.new
    end
  end
end
