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
            category: :to_do,
            default_open: true,
            lifecycle_id: 1
          },
          {
            id: 2,
            name: 'In progress',
            color: '#1f75cb',
            category: :in_progress,
            lifecycle_id: 1
          },
          {
            id: 3,
            name: 'Done',
            color: '#108548',
            category: :done,
            default_closed: true,
            lifecycle_id: 1
          },
          {
            id: 4,
            name: "Won't do",
            color: '#DD2B0E',
            category: :cancelled,
            lifecycle_id: 1
          },
          {
            id: 5,
            name: 'Duplicate',
            color: '#DD2B0E',
            category: :cancelled,
            default_duplicated: true,
            position: 10,
            lifecycle_id: 1
          }
        ].freeze

        attribute :id, :integer
        attribute :name, :string
        attribute :color, :string
        attribute :category
        attribute :position, :integer, default: 0
        attribute :default_open, :boolean, default: false
        attribute :default_closed, :boolean, default: false
        attribute :default_duplicated, :boolean, default: false
        attribute :lifecycle_id, :integer

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
