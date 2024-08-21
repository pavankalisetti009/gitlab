# frozen_string_literal: true

module SecretsManagement
  class SecretsManagerClient
    include Gitlab::Utils::StrongMemoize

    ApiError = Class.new(StandardError)

    def enable_secrets_engine(mount_path, type)
      handle_request do
        system_api.mounts_enable_secrets_engine(
          mount_path,
          OpenbaoClient::MountsEnableSecretsEngineRequest.new(type: type)
        )
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
  end
end
