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

      validates :work_item_id, presence: true, unless: -> { validation_context == :status_callback }

      validate :validate_status_exists
      validate :validate_allowed_status

      # As part of iteration 1, we only handle system-defined statuses
      # See the POC MR details to handle custom statuses in iteration 2
      # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/178180
      scope :for_work_items_with_statuses, ->(work_item_ids) { where(work_item_id: work_item_ids) }

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

      def validate_allowed_status
        # In the future also check that custom status is allowed.
        return if system_defined_status.nil?
        return if system_defined_status.allowed_for_work_item?(work_item)

        errors.add(:system_defined_status, "not allowed for this work item type")
      end
    end
  end
end
