# frozen_string_literal: true

module SecretsManagement
  class SecretsManagerClient
    include Gitlab::Utils::StrongMemoize

    SERVER_VERSION_FILE = 'GITLAB_OPENBAO_VERSION'
    KV_VALUE_FIELD = 'value'
    DEFAULT_JWT_ROLE = 'app'
    GITLAB_JWT_AUTH_PATH = 'gitlab_rails_jwt'
    OPENBAO_TOKEN_TTL = '15m'
    OPENBAO_TOKEN_MAX_TTL = '15m'
    OPENBAO_EXPIRATION_LEEWAY = 150
    OPENBAO_NOT_BEFORE_LEEWAY = 150
    OPENBAO_RECOVERY_SHARES_THRESHOLD = 1
    OPENBAO_CLOCK_SKEW_LEEWAY = 60
    OPENBAO_INLINE_AUTH_FAILED_HEADER = "X-Vault-Inline-Auth-Failed"
    OPENBAO_INLINE_AUTH_FAILED_VALUE = "true"

    ApiError = Class.new(StandardError)
    ConnectionError = Class.new(StandardError)
    AuthenticationError = Class.new(StandardError)
    Configuration = Struct.new(:host, :base_path)

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield(configuration)
    end

    def self.expected_server_version
      path = Rails.root.join(SERVER_VERSION_FILE)
      path.read.chomp
    end

    def initialize(
      jwt:, role: DEFAULT_JWT_ROLE, auth_namespace: "", auth_mount: GITLAB_JWT_AUTH_PATH,
      use_cel_auth: false, namespace: "")
      @jwt = jwt
      @role = role
      @auth_namespace = auth_namespace
      @auth_mount = auth_mount
      @use_cel_auth = use_cel_auth
      @namespace = namespace
    end

    def enable_namespace(path, metadata: nil)
      make_request(:post, "sys/namespaces/#{path}", {
        custom_metadata: metadata
      })
    end

    def disable_namespace(path)
      make_request(:delete, "sys/namespaces/#{path}")
    end

    def with_namespace(namespace)
      SecretsManagerClient.new(jwt: @jwt, role: @role, auth_namespace: @auth_namespace, auth_mount: @auth_mount,
        use_cel_auth: @use_cel_auth, namespace: namespace)
    end

    def with_auth_namespace(auth_namespace)
      SecretsManagerClient.new(jwt: @jwt, role: @role, auth_namespace: auth_namespace, auth_mount: @auth_mount,
        use_cel_auth: @use_cel_auth, namespace: @namespace)
    end

    def enable_auth_engine(mount_path, type, allow_existing: false)
      make_request(:post, "sys/auth/#{mount_path}", { type: type })
    rescue ApiError => e
      raise e unless allow_existing
      raise e unless e.message.include? "path is already in use"

      true
    end

    def disable_auth_engine(mount_path)
      make_request(:delete, "sys/auth/#{mount_path}")
    end

    def enable_secrets_engine(mount_path, type)
      make_request(:post, "sys/mounts/#{mount_path}", { type: type })
    end

    def disable_secrets_engine(mount_path)
      make_request(:delete, "sys/mounts/#{mount_path}")
    end

    def list_secrets(mount_path, secret_path)
      result = make_request(:list, "#{mount_path}/detailed-metadata/#{secret_path}", {}, optional: true)
      return [] unless result

      result["data"]["keys"].filter_map do |key|
        metadata = result["data"]["key_info"][key]
        next unless metadata

        secret_data = { "key" => key, "metadata" => metadata }

        if block_given?
          yield(secret_data)
        else
          secret_data
        end
      end
    end

    def list_policies(type: nil)
      subdir = "/#{type}" if type
      result = make_request(:list, "sys/policies/acl#{subdir}", {}, optional: true)
      return [] unless result

      result["data"]["keys"].filter_map do |key|
        # Always skip the default policy in the root of a namespace; this is
        # managed by OpenBao and not for our consumption.
        next if (key == "default") && type.nil?

        metadata = get_policy(key)
        next unless metadata

        policy_data = { "key" => key, "metadata" => metadata }
        if block_given?
          yield(policy_data)
        else
          policy_data
        end
      end
    end

    def list_project_policies(project_id:, type: nil, &block)
      subdir = "/#{type}" if type
      subtype = "project_#{project_id}#{subdir}"
      list_policies(type: subtype, &block)
    end

    def read_secret_metadata(mount_path, secret_path)
      result = make_request(:get, "#{mount_path}/metadata/#{secret_path}", {}, optional: true)
      return unless result

      result["data"]
    end

    def update_kv_secret_metadata(mount_path, secret_path, custom_metadata, metadata_cas: nil)
      payload = { custom_metadata: custom_metadata }
      payload[:metadata_cas] = metadata_cas if metadata_cas

      make_request(
        :post,
        "#{mount_path}/metadata/#{secret_path}",
        payload
      )
    end

    def update_kv_secret(mount_path, secret_path, value, cas: nil)
      options = { cas: cas } if cas

      make_request(
        :post,
        "#{mount_path}/data/#{secret_path}",
        {
          data: { KV_VALUE_FIELD => value },
          options: options
        }
      )
    end

    def delete_kv_secret(mount_path, secret_path)
      make_request(:delete, "#{mount_path}/metadata/#{secret_path}")
    end

    def configure_jwt(mount_path, server_url, jwk_signer)
      config = {
        bound_issuer: server_url
      }

      if Rails.env.test?
        jwk_key = OpenSSL::PKey::RSA.new(jwk_signer)
        jwk_verifier = jwk_key.public_key.to_s
        config[:jwt_validation_pubkeys] = jwk_verifier
      else
        config[:oidc_discovery_url] = server_url
      end

      make_request(:post, "auth/#{mount_path}/config", config)
    end

    def update_gitlab_rails_jwt_role(openbao_url:)
      role_data = {
        role_type: "jwt",
        bound_audiences: openbao_url
      }
      url = "auth/gitlab_rails_jwt/role/app"
      make_request(:post, url, role_data)
    end

    def update_jwt_role(mount_path, role_name, **role_data)
      ttl_values = {
        token_ttl: OPENBAO_TOKEN_TTL,
        token_max_ttl: OPENBAO_TOKEN_MAX_TTL
      }

      update_jwt_role_payload = ttl_values.merge(role_data)
      url = "auth/#{mount_path}/role/#{role_name}"
      make_request(:post, url, update_jwt_role_payload)
    end

    def update_jwt_cel_role(mount_path, role_name, **role_data)
      payload = {
        name: role_name,
        expiration_leeway: OPENBAO_EXPIRATION_LEEWAY,
        not_before_leeway: OPENBAO_NOT_BEFORE_LEEWAY,
        clock_skew_leeway: OPENBAO_CLOCK_SKEW_LEEWAY
      }
      update_jwt_cel_role_payload = payload.merge(role_data)

      make_request(:post, "auth/#{mount_path}/cel/role/#{role_name}", update_jwt_cel_role_payload)
    end

    def read_jwt_role(mount_path, role_name)
      url = "auth/#{mount_path}/role/#{role_name}"
      body = make_request(:get, url)
      body["data"] if body
    end

    def read_jwt_cel_role(mount_path, role_name)
      url = "auth/#{mount_path}/cel/role/#{role_name}"
      body = make_request(:get, url)
      body["data"] if body
    end

    def delete_jwt_role(mount_path, role_name)
      url = "auth/#{mount_path}/role/#{role_name}"
      make_request(:delete, url)
    end

    def delete_jwt_cel_role(mount_path, role_name)
      url = "auth/#{mount_path}/cel/role/#{role_name}"
      make_request(:delete, url)
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
      make_request(
        :delete,
        "sys/policies/acl/#{name}",
        {},
        optional: true
      )
    end

    def init_rotate_recovery
      recovery_values = {
        secret_shares: OPENBAO_RECOVERY_SHARES_THRESHOLD,
        secret_threshold: OPENBAO_RECOVERY_SHARES_THRESHOLD
      }

      make_request(:post, rotate_recovery_url, recovery_values)
    end

    def cancel_rotate_recovery
      make_request(:delete, rotate_recovery_url)
    end

    def cel_login_jwt(mount_path:, role:, jwt:)
      url = "auth/#{mount_path}/cel/login"
      body = { role: role, jwt: jwt }
      make_request(:post, url, body)
    end

    def inline_auth_path
      ns = ""
      ns = "#{auth_namespace}/" unless auth_namespace.empty?

      if use_cel_auth
        "#{ns}auth/#{auth_mount}/cel/login"
      else
        "#{ns}auth/#{auth_mount}/login"
      end
    end

    private

    attr_reader :jwt, :role, :auth_namespace, :auth_mount, :use_cel_auth, :namespace

    # save_raw_policy and read_raw_policy handle raw (direct API responses)
    # and the get_policy/set_policy forms should be preferred as they return
    # typed (JSON-able) policies. The risk with these endpoints is that
    # direct usage with HCL will result in non-JSON-parseable policies that
    # cannot be easily modified by Rails.
    def save_raw_policy(name, value)
      make_request(
        :post,
        "sys/policies/acl/#{name}",
        {
          policy: value
        }
      )
    end

    def read_raw_policy(name)
      body = make_request(:get, "sys/policies/acl/#{name}", {}, optional: true)
      body["data"] if body
    end

    def connection
      Faraday.new(url: URI.join(configuration.host, configuration.base_path)) do |f|
        f.request :json
        f.response :json

        f.headers['X-Vault-Inline-Auth-Path'] = inline_auth_path

        f.headers['X-Vault-Inline-Auth-Parameter-token'] =
          Base64.urlsafe_encode64({ key: "jwt", value: jwt }.to_json, padding: false)

        if role.present?
          f.headers['X-Vault-Inline-Auth-Parameter-role'] =
            Base64.urlsafe_encode64({ key: "role", value: role }.to_json, padding: false)
        end
      end
    end
    strong_memoize_attr :connection

    def namespaced_url(path)
      if namespace.empty?
        path
      else
        "#{namespace}/#{path}"
      end
    end

    def make_request(method, url, params = {}, optional: false)
      path = namespaced_url(url)
      response = case method
                 when :get
                   connection.get(path, params)
                 when :list
                   connection.get(path, params.merge(list: true))
                 when :scan
                   connection.get(path, params.merge(scan: true))
                 when :delete
                   connection.delete(path, params)
                 else
                   connection.post(path, params)
                 end

      body = response.body

      handle_authentication_error!(body, response)
      handle_api_error!(body)

      if response.status == 404
        raise ApiError, 'not found' unless optional

        return
      end

      body
    rescue ::Faraday::Error => e
      raise ConnectionError, e.message
    end

    def handle_authentication_error!(body, response)
      return unless response.headers.key?(OPENBAO_INLINE_AUTH_FAILED_HEADER)
      return unless response.headers[OPENBAO_INLINE_AUTH_FAILED_HEADER] == OPENBAO_INLINE_AUTH_FAILED_VALUE

      raise AuthenticationError, body["errors"].to_sentence if body && body["errors"]&.any?

      raise AuthenticationError, "Failed to authenticate with OpenBao"
    end

    def handle_api_error!(body)
      raise ApiError, body["errors"].to_sentence if body && body["errors"]&.any?
    end

    def configuration
      self.class.configuration
    end

    def rotate_recovery_url
      "sys/rotate/recovery/init"
    end
  end
end
