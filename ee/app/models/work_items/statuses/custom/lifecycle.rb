# frozen_string_literal: true

module WorkItems
  module Statuses
    module Custom
      class Lifecycle < ApplicationRecord
        self.table_name = 'work_item_custom_lifecycles'

        include ::WorkItems::Statuses::Status

        belongs_to :namespace
        belongs_to :default_open_status, class_name: 'WorkItems::Statuses::Custom::Status'
        belongs_to :default_closed_status, class_name: 'WorkItems::Statuses::Custom::Status'
        belongs_to :default_duplicate_status, class_name: 'WorkItems::Statuses::Custom::Status'

        has_many :lifecycle_statuses,
          class_name: 'WorkItems::Statuses::Custom::LifecycleStatus',
          inverse_of: :lifecycle

        has_many :statuses,
          through: :lifecycle_statuses,
          class_name: 'WorkItems::Statuses::Custom::Status'

        has_many :type_custom_lifecycles,
          class_name: 'WorkItems::TypeCustomLifecycle'

        has_many :work_item_types,
          through: :type_custom_lifecycles,
          class_name: 'WorkItems::Type'

        before_validation :ensure_default_statuses_in_lifecycle

        validates :namespace, :default_open_status, :default_closed_status, :default_duplicate_status, presence: true
        validates :name, presence: true, length: { maximum: 255 }
        validates :name, uniqueness: { scope: :namespace_id }
        validate :validate_default_status_categories

        private

        def default_statuses
          [default_open_status, default_closed_status, default_duplicate_status].compact
        end

        def ensure_default_statuses_in_lifecycle
          return unless default_open_status && default_closed_status && default_duplicate_status

          missing_statuses = default_statuses - statuses.to_a

          statuses << missing_statuses if missing_statuses.any?
        end

        def validate_default_status_categories
          return unless default_open_status && default_closed_status && default_duplicate_status

          validate_category(:default_open_status, default_open_status)
          validate_category(:default_closed_status, default_closed_status)
          validate_category(:default_duplicate_status, default_duplicate_status)
        end

        def validate_category(attr_name, default_status)
          valid_categories = DEFAULT_STATUS_CATEGORIES[attr_name]
          return if valid_categories.include?(default_status.category.to_sym)

          errors.add(attr_name, "must be of category #{valid_categories.map(&:to_s).join(' or ')}")
        end
      end
    end
  end
end
