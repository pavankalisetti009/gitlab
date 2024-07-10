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

          if ::Feature.enabled?(:work_item_epics, resource_parent, type: :beta) &&
              resource_parent.licensed_feature_available?(:epics)
            allowed_types << 'epic'
          end

          allowed_types
        end
      end

      override :widgets
      def widgets(resource_parent)
        strong_memoize_with(:widgets, resource_parent) do
          super - unlicensed_widgets(resource_parent)
        end
      end

      private

      def unlicensed_widgets(resource_parent)
        LICENSED_WIDGETS.flat_map do |licensed_feature, widgets|
          widgets unless resource_parent.licensed_feature_available?(licensed_feature)
        end.compact
      end
    end
  end
end
