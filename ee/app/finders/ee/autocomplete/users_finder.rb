# frozen_string_literal: true

module EE
  module Autocomplete # rubocop:disable Gitlab/BoundedContexts -- FOSS finder is not bounded to a context
    module UsersFinder
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      attr_reader :include_service_accounts_for_trigger_events

      override :initialize
      def initialize(params:, current_user:, project:, group:)
        super
        @include_service_accounts_for_trigger_events = params[:include_service_accounts_for_trigger_events]
      end

      private

      override :project_users
      def project_users
        users = super

        if apply_duo_service_accounts_filter?(project)
          event_type_ids_to_hide = ::Ai::FlowTrigger::EVENT_TYPES.values - include_service_accounts_for_trigger_events
          users = users.without_duo_flows_service_accounts(project, event_type_ids_to_hide)
        end

        if project.ai_review_merge_request_allowed?(current_user)
          users = users.union_with_user(::Users::Internal.duo_code_review_bot)
        end

        users
      end

      def apply_duo_service_accounts_filter?(project)
        return false if include_service_accounts_for_trigger_events.nil?

        ::Feature.enabled?(:remove_duo_flow_service_accounts_from_autocomplete_query, project)
      end
    end
  end
end
