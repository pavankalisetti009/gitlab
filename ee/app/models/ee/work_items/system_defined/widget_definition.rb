# frozen_string_literal: true

module EE
  module WorkItems
    module SystemDefined
      module WidgetDefinition
        extend ActiveSupport::Concern

        class_methods do
          extend ::Gitlab::Utils::Override

          override :widget_types
          def widget_types
            super + %w[
              health_status
              weight
              iteration
              progress
              verification_status
              requirement_legacy
              test_reports
              color
              status
              custom_fields
              vulnerabilities
            ]
          end
        end
      end
    end
  end
end
