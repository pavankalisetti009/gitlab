# frozen_string_literal: true

module Resolvers
  module Analytics
    module Dashboards
      class VisualizationResolver < BaseResolver
        type ::Types::Analytics::Dashboards::VisualizationType, null: true

        def resolve
          object.visualization
        end
      end
    end
  end
end
