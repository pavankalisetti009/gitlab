# frozen_string_literal: true

module WorkItems
  module Statuses
    module SystemDefined
      class Lifecycle
        include ActiveModel::Model
        include ActiveModel::Attributes
        include ActiveRecord::FixedItemsModel::Model
        include GlobalID::Identification

        ITEMS = [
          {
            id: 1,
            name: 'Default',
            work_item_base_types: [:issue, :task]
          }
        ].freeze

        attribute :id, :integer
        attribute :name, :string
        attribute :work_item_base_types

        class << self
          def of_work_item_base_type(base_type)
            all.find { |item| item.for_base_type?(base_type) }
          end
        end

        def for_base_type?(base_type)
          work_item_base_types.include?(base_type)
        end

        def work_item_types
          WorkItems::Type.where(base_type: work_item_base_types)
        end

        def statuses
          Status.where(lifecycle_id: id)
        end

        def find_available_status_by_name(name)
          statuses.find { |status| status.matches_name?(name) }
        end
      end
    end
  end
end
