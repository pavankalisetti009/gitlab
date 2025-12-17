# frozen_string_literal: true

module EE
  module WorkItems
    module TypesFramework
      module SystemDefined
        module WidgetDefinition
          extend ActiveSupport::Concern
          extend ::Gitlab::Utils::Override

          WIDGETS_WITH_LICENSE = {
            'health_status' => :issuable_health_status,
            'iteration' => :iterations,
            'weight' => :issue_weights,
            'verification_status' => :requirements,
            'requirement_legacy' => :requirements,
            'test_reports' => :requirements,
            'progress' => :okrs,
            'color' => :epic_colors,
            'custom_fields' => :custom_fields,
            'vulnerabilities' => :security_dashboard,
            'status' => :work_item_status
          }.freeze

          class_methods do
            extend ::Gitlab::Utils::Override

            override :widget_types
            def widget_types
              super + WIDGETS_WITH_LICENSE.keys
            end
          end

          override :licensed?
          def licensed?(resource_parent)
            # Return true if the widget type doesn't have a license requirement.
            return super if WIDGETS_WITH_LICENSE[widget_type].nil?

            resource_parent.licensed_feature_available?(WIDGETS_WITH_LICENSE[widget_type])
          end
        end
      end
    end
  end
end
