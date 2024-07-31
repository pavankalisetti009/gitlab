# frozen_string_literal: true

module WorkItems
  module Callbacks
    class RolledupDates
      class AttributesBuilder
        def self.build(work_item, params)
          new(work_item, params).build
        end

        def initialize(work_item, params)
          @work_item = work_item
          @params = params
        end

        def build
          %i[start_date due_date].each_with_object({}) do |field, attributes|
            attributes.merge!(date_values_for(field))
            attributes.merge!(date_is_fixed_for(field))
            attributes.merge!(date_rolledup_values_for(field))
          end
        end

        private

        attr_reader :work_item, :params

        def date_values_for(field)
          return {} unless params.key?(:"#{field}_fixed")

          values = params.slice(:"#{field}_fixed")
          values[field] = params[:"#{field}_fixed"] if params[:"#{field}_is_fixed"]

          values
        end

        def date_is_fixed_for(field)
          return {} unless params.key?(:"#{field}_is_fixed")

          { "#{field}_is_fixed": Gitlab::Utils.to_boolean(params[:"#{field}_is_fixed"], default: false) }
        end

        def date_rolledup_values_for(field)
          return {} unless params.key?(:"#{field}_is_fixed")
          return {} if params[:"#{field}_is_fixed"]

          finder.attributes_for(field).slice(
            field,
            :"#{field}_sourcing_milestone_id",
            :"#{field}_sourcing_work_item_id"
          )
        end

        def finder
          @finder ||= WorkItems::Widgets::RolledupDatesFinder.new(work_item)
        end
      end
    end
  end
end
