# frozen_string_literal: true

module SecretsManagement
  class SecretsManagerClient
    include Gitlab::Utils::StrongMemoize

    SERVER_VERSION_FILE = 'GITLAB_OPENBAO_VERSION'
    KV_VALUE_FIELD = 'value'

    ApiError = Class.new(StandardError)

    def self.expected_server_version
      path = Rails.root.join(SERVER_VERSION_FILE)
      path.read.chomp
    end

    def enable_secrets_engine(mount_path, type)
      handle_request do
        system_api.mounts_enable_secrets_engine(
          mount_path,
          OpenbaoClient::MountsEnableSecretsEngineRequest.new(type: type)
        )
      end
    end

    def disable_secrets_engine(mount_path)
      handle_request do
        system_api.mounts_disable_secrets_engine(mount_path)
      end
    end

    def create_kv_secret(mount_path, secret_path, value, custom_metadata = {})
      handle_request do
        secrets_api.kv_write_data_path(
          secret_path,
          mount_path,
          OpenbaoClient::KvWriteDataPathRequest.new(
            data: { KV_VALUE_FIELD => value },
            options: {
              cas: 0
            }
          )
        )

        # NOTE: This is only temporary. Once OpenBao has the endpoint for
        # creating a secret and its metadata in one transaction, we will
        # use that instead.
        if custom_metadata&.any?
          secrets_api.kv_write_metadata_path(
            secret_path,
            mount_path,
            OpenbaoClient::KvWriteMetadataPathRequest.new(
              custom_metadata: custom_metadata
            )
          )
        end
      end
    end

    private

    def handle_request
      yield
    rescue OpenbaoClient::ApiError => e
      raise ApiError, e.message
    end

    def system_api
      OpenbaoClient::SystemApi.new
    end
    strong_memoize_attr(:system_api)

    def secrets_api
      OpenbaoClient::SecretsApi.new
    end
    strong_memoize_attr(:secrets_api)
  end
end
