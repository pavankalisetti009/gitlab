# frozen_string_literal: true

module Issuables
  class CustomField < ApplicationRecord
    enum field_type: { single_select: 0, multi_select: 1, number: 2, text: 3 }, _prefix: true

    belongs_to :namespace
    has_many :select_options, -> { order(:position) },
      class_name: 'Issuables::CustomFieldSelectOption', inverse_of: :custom_field
    has_many :work_item_type_custom_fields, class_name: 'WorkItems::TypeCustomField'
    has_many :work_item_types, class_name: 'WorkItems::Type', through: :work_item_type_custom_fields

    validates :namespace, :field_type, presence: true
    validates :name, presence: true, length: { maximum: 255 },
      uniqueness: { scope: [:namespace_id], case_sensitive: false }
  end
end
