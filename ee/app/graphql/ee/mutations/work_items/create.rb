# frozen_string_literal: true

module EE
  module Mutations
    module WorkItems
      module Create
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          argument :health_status_widget,
            ::Types::WorkItems::Widgets::HealthStatusInputType,
            required: false,
            description: 'Input for health status widget.'

          argument :iteration_widget,
            ::Types::WorkItems::Widgets::IterationInputType,
            required: false,
            description: 'Iteration widget of the work item.'

          argument :rolledup_dates_widget,
            ::Types::WorkItems::Widgets::RolledupDatesInputType,
            required: false,
            description: 'Input for rolledup dates widget.',
            alpha: { milestone: '16.9' }

          argument :color_widget, ::Types::WorkItems::Widgets::ColorInputType,
            required: false,
            description: 'Input for color widget.'
        end

        override :raise_feature_not_available_error!
        def raise_feature_not_available_error!(type)
          return super unless type.epic?

          raise ::Gitlab::Graphql::Errors::ArgumentError, 'Epic type is not available for the given group'
        end
      end
    end
  end
end
