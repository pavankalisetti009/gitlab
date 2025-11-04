# frozen_string_literal: true

module Ai
  module Catalog
    class ItemVersion < ApplicationRecord
      AGENT_SCHEMA_VERSION = 1
      AGENT_REFERENCED_FLOW_SCHEMA_VERSION = 1
      FLOW_SCHEMA_VERSION = 2
      THIRD_PARTY_FLOW_SCHEMA_VERSION = 1
      DEFINITION_ACCESSOR_PREFIX = 'def_'

      VERSION_BUMP_MAJOR = :major
      VERSION_BUMP_MINOR = :minor
      VERSION_BUMP_PATCH = :patch
      VERSION_BUMP_OPTIONS = [VERSION_BUMP_MAJOR, VERSION_BUMP_MINOR, VERSION_BUMP_PATCH].freeze

      self.table_name = "ai_catalog_item_versions"

      validates :definition, :schema_version, :version, presence: true

      validates :version, length: { maximum: 50 }
      validates :version, uniqueness: { scope: :item }
      validates :version, format: { with: /\A\d+\.\d+\.\d+\z/ }

      validate :validate_json_schema
      validate :validate_readonly

      belongs_to :item, class_name: 'Ai::Catalog::Item',
        foreign_key: :ai_catalog_item_id, inverse_of: :versions, optional: false
      belongs_to :organization, class_name: 'Organizations::Organization'

      has_many :dependencies, class_name: 'Ai::Catalog::ItemVersionDependency', inverse_of: :ai_catalog_item_version

      has_one :project, through: :item

      before_create :populate_organization

      delegate :flow?, to: :item

      def human_version
        return if version.nil?

        human_version = "v#{version}"
        return human_version if released?

        "#{human_version}-draft"
      end

      def released?
        release_date.present?
      end

      def enforce_readonly_versions?
        Feature.enabled?(:ai_catalog_enforce_readonly_versions, item.project)
      end

      def draft?
        !released?
      end

      def version_bump(bump_level)
        return if version.nil?
        raise ArgumentError, "unknown bump_level: #{bump_level}" unless bump_level.in?(VERSION_BUMP_OPTIONS)

        old_version = Gitlab::VersionInfo.parse(version)

        new_version = case bump_level.to_sym
                      when VERSION_BUMP_MAJOR
                        [old_version.major + 1, 0, 0]
                      when VERSION_BUMP_MINOR
                        [old_version.major, old_version.minor + 1, 0]
                      when VERSION_BUMP_PATCH
                        [old_version.major, old_version.minor, old_version.patch + 1]
                      end

        Gitlab::VersionInfo.new(*new_version).to_s
      end

      private

      def respond_to_missing?(name, include_private)
        name.starts_with?(DEFINITION_ACCESSOR_PREFIX) || super
      end

      def method_missing(method_name, *args, &block)
        return super unless method_name.starts_with?(DEFINITION_ACCESSOR_PREFIX)

        definition[method_name.to_s.delete_prefix(DEFINITION_ACCESSOR_PREFIX)]
      end

      def validate_json_schema
        return errors.add(:definition, s_('AICatalog|unable to validate definition')) unless item && schema_version

        JsonSchemaValidator.new({
          attributes: :definition,
          base_directory: %w[app validators json_schemas ai_catalog],
          filename: json_schema_filename,
          size_limit: 64.kilobytes,
          detail_errors: true
        }).validate(self)
      end

      def json_schema_filename
        "#{item.item_type}_v#{schema_version}"
      end

      def validate_readonly
        return unless release_date_was.present? && changed? && enforce_readonly_versions?

        errors.add(:base, s_('AICatalog|cannot be changed as it has been released'))
      end

      def populate_organization
        self.organization ||= item.organization
      end
    end
  end
end
