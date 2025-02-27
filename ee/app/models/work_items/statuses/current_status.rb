# frozen_string_literal: true

module WorkItems
  module Statuses
    class CurrentStatus < ApplicationRecord
      self.table_name = 'work_item_current_statuses'

      include ActiveRecord::FixedItemsModel::HasOne

      belongs_to :namespace # set by a trigger
      belongs_to :work_item

      belongs_to_fixed_items :system_defined_status, fixed_items_class: WorkItems::Statuses::SystemDefined::Status
      # In the future add association to custom status

      validates :work_item_id, presence: true

      validate :validate_status_exists

      def status
        # In the future select system defined status or custom status
        # based on available data and setting in root namespace.
        system_defined_status
      end

      def status=(new_status)
        # In the future set status to the correct column based on
        # the type of the provided status.
        self.system_defined_status = new_status
      end

      private

      def validate_status_exists
        # In the future check that at least one status is provided
        # If custom status is enabled on the root namespace, ensure custom status is set.
        return if system_defined_status.present?

        errors.add(:system_defined_status, "not provided or references non-existent system defined status")
      end
    end
  end
end
