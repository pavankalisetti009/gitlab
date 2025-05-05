# frozen_string_literal: true

module EE
  module Resolvers
    module WorkItemsResolver
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        argument :verification_status_widget, ::Types::WorkItems::Widgets::VerificationStatusFilterInputType,
          required: false,
          description: 'Input for verification status widget filter. Ignored if `work_items_alpha` is disabled.'
        argument :requirement_legacy_widget, ::Types::WorkItems::Widgets::RequirementLegacyFilterInputType,
          required: false,
          deprecated: { reason: 'Use work item IID filter instead', milestone: '15.9' },
          description: 'Input for legacy requirement widget filter.'
        argument :health_status, ::Types::HealthStatusFilterEnum,
          required: false,
          description: 'Health status of the work item, "none" and "any" values are supported.'
        argument :weight, GraphQL::Types::String,
          required: false,
          description: 'Weight applied to the work item, "none" and "any" values are supported.'
        argument :custom_field, [::Types::WorkItems::Widgets::CustomFieldFilterInputType],
          required: false,
          experiment: { milestone: '17.10' },
          description: 'Filter by custom fields.',
          prepare: ->(custom_fields, _ctx) { Array(custom_fields).inject({}, :merge) }
        argument :status, ::Types::WorkItems::Widgets::StatusFilterInputType,
          required: false,
          description: 'Filter by status.',
          experiment: { milestone: '18.0' }
      end

      override :resolve_with_lookahead
      def resolve_with_lookahead(**args)
        args.delete(:verification_status_widget) unless resource_parent&.work_items_alpha_feature_flag_enabled?

        super
      end

      private

      override :widget_preloads
      def widget_preloads
        super.merge(
          verification_status: { requirement: :recent_test_reports },
          progress: :progress,
          color: :color,
          test_reports: :test_reports
        )
      end
    end
  end
end
