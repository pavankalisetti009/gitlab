# frozen_string_literal: true

module WorkItems
  module Statuses
    module SystemDefined
      class Status
        include ActiveModel::Model
        include ActiveModel::Attributes
        include ActiveRecord::FixedItemsModel::Model
        include GlobalID::Identification
        include WorkItems::Statuses::SharedConstants

        ITEMS = [
          {
            id: 1,
            name: 'To do',
            color: '#737278',
            category: :to_do
          },
          {
            id: 2,
            name: 'In progress',
            color: '#1f75cb',
            category: :in_progress
          },
          {
            id: 3,
            name: 'Done',
            color: '#108548',
            category: :done
          },
          {
            id: 4,
            name: "Won't do",
            color: '#DD2B0E',
            category: :cancelled
          },
          {
            id: 5,
            name: 'Duplicate',
            color: '#DD2B0E',
            category: :cancelled,
            position: 10
          }
        ].freeze

        attribute :id, :integer
        attribute :name, :string
        attribute :color, :string
        attribute :category
        # For custom statuses position will be on the join model between
        # custom lifecycle and custom status to allow modification per lifecycle.
        # We don't plan to change the position of the status for system defined lifecycles.
        attribute :position, :integer, default: 0

        def icon_name
          CATEGORY_ICONS[category]
        end

        def matches_name?(other_name)
          name.casecmp(other_name) == 0
        end
      end
    end
  end
end
