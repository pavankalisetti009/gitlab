# frozen_string_literal: true

module Ai
  module Catalog
    class ItemVersion < ApplicationRecord
      include SafelyChangeColumnDefault

      AGENT_SCHEMA_VERSION = 1

      self.table_name = "ai_catalog_item_versions"

      columns_changing_default :definition

      validates :definition, :schema_version, :version, presence: true

      validates :version, length: { maximum: 50 }
      validates :version, uniqueness: { scope: :item }

      validates :definition, json_schema: { filename: 'ai_catalog_item_version_definition', size_limit: 64.kilobytes }

      belongs_to :item, class_name: 'Ai::Catalog::Item',
        foreign_key: :ai_catalog_item_id, inverse_of: :versions, optional: false, autosave: true
      belongs_to :organization, class_name: 'Organizations::Organization'

      before_create :populate_organization

      private

      def populate_organization
        self.organization ||= item.organization
      end
    end
  end
end
