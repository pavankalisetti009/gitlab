# frozen_string_literal: true

module Issuables
  class CustomField < ApplicationRecord
    include Gitlab::SQL::Pattern

    enum field_type: { single_select: 0, multi_select: 1, number: 2, text: 3 }, _prefix: true

    belongs_to :namespace
    has_many :select_options, -> { order(:position) },
      class_name: 'Issuables::CustomFieldSelectOption', inverse_of: :custom_field
    has_many :work_item_type_custom_fields, class_name: 'WorkItems::TypeCustomField'
    has_many :work_item_types, -> { order(:name) },
      class_name: 'WorkItems::Type', through: :work_item_type_custom_fields

    validates :namespace, :field_type, presence: true
    validates :name, presence: true, length: { maximum: 255 },
      uniqueness: { scope: [:namespace_id], case_sensitive: false }

    scope :of_namespace, ->(namespace) { where(namespace_id: namespace) }
    scope :active, -> { where(archived_at: nil) }
    scope :archived, -> { where.not(archived_at: nil) }
    scope :ordered_by_status_and_name, -> { order(Arel.sql('archived_at IS NULL').desc, name: :asc) }

    class << self
      def without_any_work_item_types
        where_not_exists(associated_work_item_type_relation)
      end

      def with_work_item_types(work_item_types)
        return without_any_work_item_types if work_item_types.empty?

        work_item_types.inject(self) do |relation, work_item_type|
          relation.where_exists(associated_work_item_type_relation(work_item_type: work_item_type))
        end
      end

      private

      def associated_work_item_type_relation(work_item_type: nil)
        work_item_type_custom_field_table = WorkItems::TypeCustomField.arel_table

        relation = WorkItems::TypeCustomField
          .where(work_item_type_custom_field_table[:namespace_id].eq(arel_table[:namespace_id]))
          .where(work_item_type_custom_field_table[:custom_field_id].eq(arel_table[:id]))

        relation = relation.where(work_item_type_id: work_item_type) if work_item_type

        relation
      end
    end

    def active?
      archived_at.nil?
    end
  end
end
