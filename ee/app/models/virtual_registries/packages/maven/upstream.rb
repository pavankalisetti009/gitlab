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

        SAME_URL_AND_CREDENTIALS_ERROR = 'already has a remote upstream with the same url and credentials'
        SAME_LOCAL_PROJECT_OR_GROUP_ERROR = 'already has a local upstream with the same target project or group'

        ALLOWED_GLOBAL_ID_CLASSES = [::Project, ::Group].freeze

        belongs_to :group
        has_many :registry_upstreams,
          class_name: 'VirtualRegistries::Packages::Maven::RegistryUpstream',
          inverse_of: :upstream,
          autosave: true
        has_many :registries, class_name: 'VirtualRegistries::Packages::Maven::Registry', through: :registry_upstreams
        has_many :cache_entries,
          class_name: 'VirtualRegistries::Packages::Maven::Cache::Entry',
          inverse_of: :upstream

        has_many :cache_local_entries,
          class_name: 'VirtualRegistries::Packages::Maven::Cache::Local::Entry',
          inverse_of: :upstream

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

        def cache_entries
          remote? ? super : super.none
        end

        def cache_local_entries
          local? ? super : super.none
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
          cache_entries.default
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
          ::VirtualRegistries::Packages::Cache::MarkEntriesForDestructionWorker.perform_async(id)
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

        def local_project
          return unless local?
          return unless global_id_url&.model_class == Project

          GlobalID::Locator.locate(url)
        end
        strong_memoize_attr :local_project

        def local_group
          return unless local?
          return unless global_id_url&.model_class == Group

          GlobalID::Locator.locate(url)
        end
        strong_memoize_attr :local_group

        def url=(value)
          super

          clear_memoization(:global_id_url)
          clear_memoization(:local_project)
          clear_memoization(:local_group)
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
          self.url = url.sub(TRAILING_SLASHES_REGEX, '')
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

          return if self.class.for_group(group)
            .select(:username, :password)
            .then { |q| new_record? ? q : q.where.not(id:) }
            .where(url:)
            .none? { |u| u.username == username && Rack::Utils.secure_compare(u.password.to_s, password.to_s) }

          errors.add(:group, remote? ? SAME_URL_AND_CREDENTIALS_ERROR : SAME_LOCAL_PROJECT_OR_GROUP_ERROR)
        end

        def ensure_local_project_or_local_group
          return errors.add(:url, 'is invalid') unless global_id_url

          unless global_id_url.model_class.in?(ALLOWED_GLOBAL_ID_CLASSES)
            return errors.add(:url, 'should point to a Project or Group')
          end

          return if global_id_url.model_class.exists?(global_id_url.model_id)

          errors.add(:url, "should point to an existing #{global_id_url.model_class.name}")
        end

        def global_id_url
          GlobalID.parse(url)
        end
        strong_memoize_attr :global_id_url
      end
    end
  end
end
