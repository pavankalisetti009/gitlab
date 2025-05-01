# frozen_string_literal: true

module WorkItems
  module Statuses
    module Custom
      class Status < ApplicationRecord
        self.table_name = 'work_item_custom_statuses'

        include WorkItems::Statuses::SharedConstants
        include WorkItems::Statuses::Status

        MAX_STATUSES_PER_NAMESPACE = 70

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
        # Update doesn't change the overall status per namespace count
        # because you won't be able to change the namespace through the API.
        validate :validate_statuses_per_namespace_limit, on: :create

        def icon_name
          CATEGORY_ICONS[category.to_sym]
        end

        def position
          # Temporarily default to 0 as it is not meaningful without lifecycle context
          0
        end

        private

        def validate_statuses_per_namespace_limit
          return unless namespace.present?
          return unless Status.where(namespace_id: namespace.id).count >= MAX_STATUSES_PER_NAMESPACE

          errors.add(:namespace,
            format(_('can only have a maximum of %{limit} statuses.'), limit: MAX_STATUSES_PER_NAMESPACE)
          )
        end
      end
    end
  end
end
