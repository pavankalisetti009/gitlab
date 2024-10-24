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

    def expect_kv_secret_engine_to_be_mounted(path)
      expect { secrets_manager_client.read_secrets_engine_configuration(path) }.not_to raise_error
    end

    def secrets_manager_client
      SecretsManagerClient.new
    end
  end
end
