# frozen_string_literal: true

module Ai
  module Catalog
    class ItemVersionDependency < ApplicationRecord
      self.table_name = 'ai_catalog_item_version_dependencies'

      belongs_to :ai_catalog_item_version, class_name: 'Ai::Catalog::ItemVersion', optional: false
      belongs_to :dependency, class_name: 'Ai::Catalog::Item', inverse_of: :reverse_dependencies, optional: false
      belongs_to :organization, class_name: 'Organizations::Organization', optional: false
    end
  end
end
