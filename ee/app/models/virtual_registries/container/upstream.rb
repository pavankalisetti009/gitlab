# frozen_string_literal: true

module VirtualRegistries
  module Container
    class Upstream < ::VirtualRegistries::Upstream
      include Gitlab::SQL::Pattern

      TOKEN_REQUEST_TIMEOUT = 10.seconds
      BEARER_TOKEN_CACHE_DURATION = 3.minutes
      AUTH_CHALLENGE_REGEX = /(\w+)="([^"]+)"/

      REGISTRY_ACCEPT_HEADERS = {
        'Accept' => [
          'application/vnd.docker.distribution.manifest.v2+json',
          'application/vnd.docker.distribution.manifest.list.v2+json',
          'application/vnd.oci.image.manifest.v1+json',
          'application/vnd.oci.image.index.v1+json'
        ].join(',')
      }.freeze

      has_many :registry_upstreams,
        class_name: '::VirtualRegistries::Container::RegistryUpstream',
        inverse_of: :upstream,
        autosave: true
      has_many :registries, class_name: '::VirtualRegistries::Container::Registry', through: :registry_upstreams
      has_many :cache_entries,
        class_name: '::VirtualRegistries::Container::Cache::Entry',
        inverse_of: :upstream

      encrypts :username, :password

      validates :username, presence: true, if: :password?
      validates :password, presence: true, if: :username?
      validates :username, :password, length: { maximum: 510 }
      validate :credentials_uniqueness_for_group, if: -> { %i[url username password].any? { |f| changes.key?(f) } }

      prevent_from_serialization(:password)

      scope :search_by_name, ->(query) { fuzzy_search(query, [:name], use_minimum_char_limit: false) }

      def url_for(path)
        base_url = url.chomp('/').delete_suffix('/v2')

        full_url = File.join(base_url, 'v2', path.to_s)
        Addressable::URI.parse(full_url).to_s
      end

      def headers(path)
        bearer_token = get_bearer_token(path)

        return {} unless bearer_token.present?

        { 'Authorization' => "Bearer #{bearer_token}" }.merge(REGISTRY_ACCEPT_HEADERS)
      end

      def default_cache_entries
        cache_entries.default
      end

      def purge_cache!
        ::VirtualRegistries::Container::Cache::MarkEntriesForDestructionWorker.perform_async(id)
      end

      private

      def get_bearer_token(path)
        Rails.cache.fetch(
          bearer_token_cache_key(path),
          expires_in: BEARER_TOKEN_CACHE_DURATION
        ) do
          exchange_credentials_for_bearer_token(path).presence
        end
      end

      def exchange_credentials_for_bearer_token(path)
        # Step 1: Request for file and get an authenticate header
        auth_challenge = get_auth_challenge(path)
        return unless auth_challenge

        # Step 2: Parse authentication URL and params from header
        token_service_info = parse_auth_challenge(auth_challenge)
        return unless token_service_info

        # Step 3: Exchange credentials for bearer token at authentication URL
        request_bearer_token(token_service_info)
      end

      def get_auth_challenge(path)
        response = ::Gitlab::HTTP.head(
          url_for(path),
          follow_redirects: true,
          timeout: TOKEN_REQUEST_TIMEOUT
        )

        response.headers.find { |k, _| k.casecmp('www-authenticate') == 0 }&.last if response.unauthorized?
      rescue *::Gitlab::HTTP::HTTP_ERRORS => e
        Gitlab::ErrorTracking.track_exception(e,
          message: "Failed to get auth challenge for upstream #{id}: #{e.message}")
        nil
      end

      def parse_auth_challenge(auth_header)
        auth_header = auth_header.first if auth_header.is_a?(Array)

        # Auth header format: Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/alpine:pull"
        return unless auth_header&.start_with?('Bearer ')

        # Extract realm, service, and scope using regex
        params = auth_header.scan(AUTH_CHALLENGE_REGEX).to_h.transform_keys(&:downcase)

        return unless params['realm'] && params['service']

        params
      end

      def request_bearer_token(token_service_info)
        scope = token_service_info['scope']

        token_url = "#{token_service_info['realm']}?service=#{token_service_info['service']}"
        token_url << "&scope=#{scope}" if scope.present?

        response = ::Gitlab::HTTP.get(
          token_url,
          headers: basic_auth_headers,
          follow_redirects: true,
          timeout: TOKEN_REQUEST_TIMEOUT
        )

        return unless response.success?

        token_data = ::Gitlab::Json.parse(response.body)
        token_data['token'].presence || token_data['access_token'].presence
      rescue JSON::ParserError => e
        Gitlab::ErrorTracking.track_exception(e,
          message: "Failed to parse token response for upstream #{id}: #{e.message}")
        nil
      rescue *::Gitlab::HTTP::HTTP_ERRORS => e
        Gitlab::ErrorTracking.track_exception(e, message: "Token request error for upstream #{id}: #{e.message}")
        nil
      end

      def basic_auth_headers
        return {} unless username.present? && password.present?

        authorization = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)

        { 'Authorization' => authorization }
      end

      def bearer_token_cache_key(path)
        cache_key_data = [id, username, path, Digest::SHA256.hexdigest(password.to_s)].join(':')

        "container:virtual_registry:bearer_token:#{cache_key_data}"
      end

      def credentials_uniqueness_for_group
        return unless group

        return if self.class.for_group(group)
          .select(:username, :password)
          .then { |q| new_record? ? q : q.where.not(id:) }
          .where(url:)
          .none? { |u| u.username == username && Rack::Utils.secure_compare(u.password.to_s, password.to_s) }

        errors.add(:group, 'already has an upstream with the same credentials')
      end
    end
  end
end
