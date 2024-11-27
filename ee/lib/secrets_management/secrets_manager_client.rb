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

    def get_policy(name)
      policy = read_raw_policy name
      return AclPolicy.new(name) if policy.nil?

      parsed = Gitlab::Json.parse(policy["policy"])
      AclPolicy.build_from_hash(name, parsed)
    end

    def set_policy(policy)
      save_raw_policy(policy.name, policy.to_openbao_attributes.to_json)
    end

    def delete_policy(name)
      handle_optional_request do
        system_api.policies_delete_acl_policy(name)
      end
    end

    private

    def handle_request
      yield
    rescue OpenbaoClient::ApiError => e
      raise ApiError, e.message
    end

    # handle_optional_request returns nil rather than having the OpenAPI
    # client raise an exception; returning (nil, nil) from a request handler
    # in OpenBao gets translated to a 404 response, even if the path was
    # otherwise valid.
    def handle_optional_request
      yield
    rescue OpenbaoClient::ApiError => e
      return if e.code == 404

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

    # save_raw_policy and read_raw_policy handle raw (direct API responses)
    # and the get_policy/set_policy forms should be preferred as they return
    # typed (JSON-able) policies. The risk with these endpoints is that
    # direct usage with HCL will result in non-JSON-parseable policies that
    # cannot be easily modified by Rails.
    def save_raw_policy(name, value)
      handle_request do
        system_api.policies_write_acl_policy(
          name,
          OpenbaoClient::PoliciesWriteAclPolicyRequest.new(
            policy: value
          )
        )
      end
    end

    def read_raw_policy(name)
      handle_optional_request do
        body = system_api.policies_read_acl_policy(name, debug_return_type: "String")
        Gitlab::Json.parse(body)["data"]
      end
    end
  end
end
