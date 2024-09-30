# frozen_string_literal: true

module WorkItems
  class TypeCustomField < ApplicationRecord
    self.table_name = 'work_item_type_custom_fields'

    belongs_to :namespace
    belongs_to :work_item_type, class_name: 'WorkItems::Type'
    belongs_to :custom_field, class_name: 'Issuables::CustomField'

    validates :namespace, :work_item_type, presence: true
    validates :custom_field, presence: true, uniqueness: { scope: [:namespace_id, :work_item_type_id] }
  end
end
