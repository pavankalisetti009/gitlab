# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      class Upstream < ApplicationRecord
        include Gitlab::SQL::Pattern
        include Gitlab::Utils::StrongMemoize

        TEST_PATH = 'com/company/app/maven-metadata.xml'
        MAVEN_CENTRAL_URL = 'https://repo1.maven.org/maven2'
        TRAILING_SLASHES_REGEX = %r{/+$}
        DEFAULT_PORTS = { 'https' => 443, 'http' => 80 }.freeze

        SAME_URL_AND_CREDENTIALS_ERROR = 'already has a remote upstream with the same url and credentials'
        SAME_LOCAL_PROJECT_OR_GROUP_ERROR = 'already has a local upstream with the same target project or group'

        ALLOWED_GLOBAL_ID_CLASSES = [::Project, ::Group].freeze

        belongs_to :group
        has_many :registry_upstreams,
          class_name: 'VirtualRegistries::Packages::Maven::RegistryUpstream',
          inverse_of: :upstream,
          autosave: true
        has_many :registries, class_name: 'VirtualRegistries::Packages::Maven::Registry', through: :registry_upstreams
        has_many :cache_remote_entries,
          class_name: 'VirtualRegistries::Packages::Maven::Cache::Remote::Entry',
          inverse_of: :upstream
        has_many :rules,
          class_name: 'VirtualRegistries::Packages::Maven::Upstream::Rule',
          inverse_of: :remote_upstream

        encrypts :username, :password

        validates :group, top_level_group: true, presence: true
        validates :url, presence: true, length: { maximum: 255 }
        validates :username, :password, length: { maximum: 510 }
        validates :cache_validity_hours, numericality: { greater_than_or_equal_to: 0, only_integer: true }
        validates :metadata_cache_validity_hours, numericality: { greater_than: 0, only_integer: true }
        validates :name, presence: true, length: { maximum: 255 }
        validates :description, length: { maximum: 1024 }
        validate :credentials_uniqueness_for_group, if: -> { %i[url username password].any? { |f| changes.key?(f) } }

        # remote validations
        validates :url, addressable_url: {
          allow_localhost: false,
          allow_local_network: false,
          dns_rebind_protection: true,
          enforce_sanitization: true
        }, if: :remote?
        validates :username, presence: true, if: -> { remote? && password? }
        validates :password, presence: true, if: -> { remote? && username? }

        # local validations
        with_options if: :local? do
          validates :username, absence: true
          validates :password, absence: true
          validate :ensure_local_project_or_local_group
        end

        before_validation :normalize_url, if: -> { url? && remote? }
        before_validation :set_cache_validity_hours_for_maven_central, if: :url?, on: :create
        before_validation :restore_password!, if: -> { remote? && username? && !password? && !username_changed? },
          on: :update

        after_validation :reset_credentials, if: -> { persisted? && url_changed? }

        prevent_from_serialization(:password) if respond_to?(:prevent_from_serialization)

        scope :eager_load_registry_upstream, ->(registry:) {
          eager_load(:registry_upstreams)
            .where(registry_upstreams: { registry: })
            .order('registry_upstreams.position ASC')
        }

        scope :for_group, ->(group) { where(group:) }
        scope :for_url, ->(url) { where(url:) }
        scope :for_id_and_group, ->(id:, group:) { where(id:, group:) }
        scope :search_by_name, ->(query) { fuzzy_search(query, [:name], use_minimum_char_limit: false) }

        def cache_remote_entries
          remote? ? super : super.none
        end

        def cache_local_entries
          # TODO use the association when the related table is restored -- https://gitlab.com/gitlab-org/gitlab/-/work_items/583722
          []
        end

        def url_for(path)
          return unless remote?

          full_url = File.join(url, path)
          Addressable::URI.parse(full_url).to_s
        end

        def headers(_ = nil)
          return {} unless username.present? && password.present?

          authorization = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)

          { Authorization: authorization }
        end

        def default_cache_entries
          cache_remote_entries.for_group(group_id).default
        end

        def object_storage_key
          return unless remote?

          hash = Digest::SHA2.hexdigest(SecureRandom.uuid)
          Gitlab::HashedPath.new(
            'virtual_registries',
            'packages',
            'maven',
            group_id,
            'upstream',
            id,
            'cache',
            'entry',
            hash[0..1],
            hash[2..3],
            hash[4..],
            root_hash: group_id
          ).to_s
        end

        def purge_cache!
          ::VirtualRegistries::Cache::MarkEntriesForDestructionWorker.perform_async(to_global_id.to_s)
        end

        def test
          return { success: true } if local? # local upstreams can't be tested so they always pass the test

          relative_path = new_record? ? TEST_PATH : (default_cache_entries.pick(:relative_path) || TEST_PATH)

          response = Gitlab::HTTP.head(
            url_for(relative_path),
            headers: headers,
            follow_redirects: true
          )

          case response.code
          when 404, 200..299 then { success: true }
          else
            { success: false, result: "Error: #{response.code} - #{response.message}" }
          end
        rescue *::Gitlab::HTTP::HTTP_ERRORS => e
          { success: false, result: "Error: #{e.message}" }
        end

        def local_project?
          return false unless local?

          local_global_id&.model_class == Project
        end

        def local_project_id
          return unless local_project?

          local_global_id&.model_id&.to_i
        end

        def local_group?
          return false unless local?

          local_global_id&.model_class == Group
        end

        def local_group_id
          return unless local_group?

          local_global_id&.model_id&.to_i
        end

        def url=(value)
          super

          clear_memoization(:local_global_id)
        end

        def local?
          url&.start_with?('gid://')
        end

        def remote?
          !local?
        end

        def destroy_and_sync_positions
          transaction do
            ::VirtualRegistries::Packages::Maven::RegistryUpstream.sync_higher_positions(registry_upstreams)
            destroy
          end
        end

        private

        def normalize_url
          uri = URI.parse(url.strip)

          # Preserve userinfo - Ruby URI clears it when host or port are modified
          saved_userinfo = uri.userinfo

          # Normalize host: downcase (hostnames are case-insensitive per RFC 3986)
          uri.host = uri.host&.downcase

          # Normalize path: handle both .git/ and /.git patterns
          # Order: slashes, .git, slashes (handles all combinations)
          uri.path = uri.path
            .sub(TRAILING_SLASHES_REGEX, '') # /maven2.git/ -> /maven2.git
            .chomp('.git') # /maven2.git -> /maven2
            .sub(TRAILING_SLASHES_REGEX, '') # /maven2/ -> /maven2 (for /.git case)

          # Remove default ports (443 for https, 80 for http)
          uri.port = nil if uri.port == DEFAULT_PORTS[uri.scheme]

          # Restore userinfo after all modifications (host= and port= both clear it)
          uri.userinfo = saved_userinfo if saved_userinfo

          self.url = uri.to_s
        rescue URI::InvalidURIError => e
          Gitlab::AppLogger.warn(
            message: 'Failed to normalize upstream URL',
            url: url,
            error: e.message
          )
        end

        def protocol_variant_url
          return unless url.present?

          case url
          when /\Ahttps:/
            url.sub(/\Ahttps:/, 'http:')
          when /\Ahttp:/
            url.sub(/\Ahttp:/, 'https:')
          end
        end

        def credentials_match?(other)
          other.username == username &&
            Rack::Utils.secure_compare(other.password.to_s, password.to_s)
        end

        def reset_credentials
          return if username_changed? && password_changed?

          self.username = nil
          self.password = nil
        end

        def set_cache_validity_hours_for_maven_central
          return unless url.start_with?(MAVEN_CENTRAL_URL)

          self.cache_validity_hours = 0
        end

        def credentials_uniqueness_for_group
          return unless group

          if remote?
            # Build list of URL variants to check (current URL + protocol variation)
            urls_to_check = [url, protocol_variant_url].compact.uniq

            existing_match = self.class.for_group(group)
              .where(url: urls_to_check)
              .then { |q| new_record? ? q : q.where.not(id:) }
              .find { |upstream| credentials_match?(upstream) }

            return unless existing_match

            errors.add(:group, SAME_URL_AND_CREDENTIALS_ERROR)
          else
            # Local upstream: check for same project/group URL
            return if self.class.for_group(group)
              .where(url:)
              .then { |q| new_record? ? q : q.where.not(id:) }
              .none?

            errors.add(:group, SAME_LOCAL_PROJECT_OR_GROUP_ERROR)
          end
        end

        def ensure_local_project_or_local_group
          return errors.add(:url, 'is invalid') unless local_global_id

          unless local_global_id.model_class.in?(ALLOWED_GLOBAL_ID_CLASSES)
            return errors.add(:url, 'should point to a Project or Group')
          end

          return if local_global_id.model_class.exists?(local_global_id.model_id)

          errors.add(:url, "should point to an existing #{local_global_id.model_class.name}")
        end

        def local_global_id
          GlobalID.parse(url)
        end
        strong_memoize_attr :local_global_id
      end
    end
  end
end
