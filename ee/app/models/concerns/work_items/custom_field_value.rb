# frozen_string_literal: true

module WorkItems
  module CustomFieldValue
    extend ActiveSupport::Concern

    included do
      self.table_name_prefix = "work_item_"

      belongs_to :namespace
      belongs_to :work_item
      belongs_to :custom_field, class_name: 'Issuables::CustomField'

      before_validation :copy_namespace_from_work_item

      validates :namespace, :work_item, :custom_field, presence: true
    end

    private

    def copy_namespace_from_work_item
      self.namespace = work_item&.namespace
    end
  end
end
