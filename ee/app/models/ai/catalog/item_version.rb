# frozen_string_literal: true

module Ai
  module Catalog
    class ItemVersion < ApplicationRecord
      include SafelyChangeColumnDefault

      AGENT_SCHEMA_VERSION = 1
      DEFINITION_ACCESSOR_PREFIX = 'def_'

      self.table_name = "ai_catalog_item_versions"

      columns_changing_default :definition

      validates :definition, :schema_version, :version, presence: true

      validates :version, length: { maximum: 50 }
      validates :version, uniqueness: { scope: :item }

      validate :validate_json_schema

      validate :validate_readonly

      belongs_to :item, class_name: 'Ai::Catalog::Item',
        foreign_key: :ai_catalog_item_id, inverse_of: :versions, optional: false, autosave: true
      belongs_to :organization, class_name: 'Organizations::Organization'

      before_create :populate_organization

      def human_version
        return if version.nil?

        human_version = "v#{version}"
        return human_version if released?

        "#{human_version}-draft"
      end

      def released?
        release_date.present?
      end

      def draft?
        !released?
      end

      def readonly?
        super || release_date_was.present?
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
        return errors.add(:definition, s_('AICatalog|unable to validate definition')) unless item

        JsonSchemaValidator.new({
          attributes: :definition,
          base_directory: %w[app validators json_schemas ai_catalog],
          filename: json_schema_filename,
          size_limit: 64.kilobytes,
          detail_errors: true
        }).validate(self)
      end

      def json_schema_filename
        "#{item.item_type}_v#{schema_version || 1}"
      end

      def validate_readonly
        return unless readonly? && changed?

        errors.add(:base, s_('AICatalog|cannot change a released item version'))
      end

      def populate_organization
        self.organization ||= item.organization
      end
    end
  end
end
