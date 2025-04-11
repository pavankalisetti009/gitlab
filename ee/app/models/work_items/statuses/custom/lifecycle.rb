# frozen_string_literal: true

module WorkItems
  module Statuses
    module Custom
      class Lifecycle < ApplicationRecord
        self.table_name = 'work_item_custom_lifecycles'

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

        validates :namespace, :default_open_status, :default_closed_status, :default_duplicate_status, presence: true
        validates :name, presence: true, length: { maximum: 255 }
        validates :name, uniqueness: { scope: :namespace_id }

        # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/524078
        # validate :default_statuses_in_lifecycle
      end
    end
  end
end
