# frozen_string_literal: true

module SecretsManagement
  class TestClient < SecretsManagerClient
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

    def each_acl_policy
      handle_request do
        body, _, _ = system_api.policies_list_acl_policies("true", debug_return_type: "String")
        data = Gitlab::Json.parse(body)["data"]
        data["keys"].each do |policy|
          yield(policy)
        end
      end
    end

    def read_kv_secret_value(mount_path, secret_path, version: nil)
      handle_request do
        body, _, _ = secrets_api.kv_read_data_path_with_http_info(
          secret_path,
          mount_path,
          version: version,
          debug_return_type: "String"
        )
        Gitlab::Json.parse(body).dig("data", "data", KV_VALUE_FIELD)
      end
    end

    def read_kv_secret_custom_metadata(mount_path, secret_path)
      handle_request do
        body, _, _ = secrets_api.kv_read_metadata_path_with_http_info(
          secret_path,
          mount_path,
          debug_return_type: "String"
        )
        Gitlab::Json.parse(body).dig('data', 'custom_metadata')
      end
    end
  end
end
