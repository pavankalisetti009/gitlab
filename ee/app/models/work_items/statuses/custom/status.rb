# frozen_string_literal: true

module WorkItems
  module Statuses
    module Custom
      class Status < ApplicationRecord
        self.table_name = 'work_item_custom_statuses'

        include ::WorkItems::Statuses::Status

        enum category: CATEGORIES

        belongs_to :namespace

        has_many :lifecycle_statuses,
          class_name: 'WorkItems::Statuses::Custom::LifecycleStatus',
          inverse_of: :status

        has_many :lifecycles,
          through: :lifecycle_statuses,
          class_name: 'WorkItems::Statuses::Custom::Lifecycle'

        validates :namespace, :category, presence: true
        validates :name, presence: true, length: { maximum: 255 }
        validates :name, uniqueness: { scope: :namespace_id }
        validates :color, presence: true, length: { maximum: 7 }, color: true
      end
    end
  end
end
