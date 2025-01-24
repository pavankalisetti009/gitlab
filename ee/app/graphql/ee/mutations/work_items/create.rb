# frozen_string_literal: true

module EE
  module Mutations
    module WorkItems
      module Create
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          argument :weight_widget,
            ::Types::WorkItems::Widgets::WeightInputType,
            required: false,
            description: 'Input for weight widget.'

          argument :health_status_widget,
            ::Types::WorkItems::Widgets::HealthStatusInputType,
            required: false,
            description: 'Input for health status widget.'

          argument :iteration_widget,
            ::Types::WorkItems::Widgets::IterationInputType,
            required: false,
            description: 'Iteration widget of the work item.'

          argument :color_widget, ::Types::WorkItems::Widgets::ColorInputType,
            required: false,
            description: 'Input for color widget.'

          argument :custom_fields_widget, [::Types::WorkItems::Widgets::CustomFieldValueInputType],
            required: false,
            description: 'Input for custom fields widget.',
            experiment: { milestone: '17.10' }

          argument :vulnerability_id, ::Types::GlobalIDType[::Vulnerability],
            required: false,
            description: 'Input for linking an existing vulnerability to created work item.',
            experiment: { milestone: '17.9' }
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
