# frozen_string_literal: true

module EE
  module WorkItems
    module Type
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      LICENSED_WIDGETS = {
        iterations: ::WorkItems::Widgets::Iteration,
        issue_weights: ::WorkItems::Widgets::Weight,
        requirements: [
          ::WorkItems::Widgets::Status,
          ::WorkItems::Widgets::RequirementLegacy,
          ::WorkItems::Widgets::TestReports
        ],
        issuable_health_status: ::WorkItems::Widgets::HealthStatus,
        okrs: ::WorkItems::Widgets::Progress,
        epic_colors: ::WorkItems::Widgets::Color
      }.freeze

      class_methods do
        extend ::Gitlab::Utils::Override

        override :allowed_group_level_types
        def allowed_group_level_types(resource_parent)
          allowed_types = super

          if ::Feature.enabled?(:work_item_epics, resource_parent.root_ancestor, type: :beta) &&
              resource_parent.licensed_feature_available?(:epics)
            allowed_types << 'epic'
          end

          allowed_types
        end
      end

      override :widgets
      def widgets(resource_parent)
        strong_memoize_with(:widgets, resource_parent) do
          unlicensed_classes = unlicensed_widget_classes(resource_parent)

          if epic? && !resource_parent.try(:work_items_beta_feature_flag_enabled?)
            unlicensed_classes << ::WorkItems::Widgets::Assignees
          end

          super.reject { |widget_def| unlicensed_classes.include?(widget_def.widget_class) }
        end
      end

      private

      def unlicensed_widget_classes(resource_parent)
        LICENSED_WIDGETS.flat_map do |licensed_feature, widget_class|
          widget_class unless resource_parent.licensed_feature_available?(licensed_feature)
        end.compact
      end
    end
  end
end
