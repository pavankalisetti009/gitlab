# frozen_string_literal: true

module SecretsManagement
  class SecretsManagerClient
    include Gitlab::Utils::StrongMemoize

    SERVER_VERSION_FILE = 'GITLAB_OPENBAO_VERSION'

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

    def read_secrets_engine_configuration(mount_path)
      handle_request do
        system_api.mounts_read_configuration(mount_path)
      end
    end

    def each_secrets_engine
      handle_request do
        body, _, _ = system_api.mounts_list_secrets_engines_with_http_info(debug_return_type: "String")
        data = Gitlab::Json.parse(body)["data"]
        data.each do |path, info|
          yield(path, info)
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
  end
end
