# frozen_string_literal: true

module Ai
  module FlowTriggers
    class BaseService
      attr_reader :project, :current_user

      def execute(params)
        service_account = User.find(params[:user_id])

        unless user_is_authorized_to_service_account?(service_account)
          return ServiceResponse.error(message: 'You are not authorized to use this service account in this project')
        end

        trigger = yield

        if trigger.valid?
          enforce_composite_identity!(service_account)

          ServiceResponse.success(payload: trigger)
        else
          ServiceResponse.error(message: trigger.errors.full_messages.to_sentence)
        end
      end

      private

      def user_is_authorized_to_service_account?(service_account)
        return false unless service_account.service_account?

        group = service_account.provisioned_by_group

        return false unless group
        return false unless group.root_ancestor.id == project.root_ancestor.id

        Ability.allowed?(current_user, :manage_ai_flow_triggers, project)
      end

      def enforce_composite_identity!(service_account)
        service_account.update!(
          composite_identity_enforced: Feature.enabled?(:ai_flow_triggers_use_composite_identity, current_user)
        )
      end

      # Triggers for "manual" External Agents can only be created by users who can create External Agents.
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/583687.
      def new_external_agents_allowed?
        Feature.enabled?(:ai_catalog_create_third_party_flows, current_user)
      end

      def disallow_new_external_agent_error
        ServiceResponse.error(message: 'You have insufficient permissions')
      end
    end
  end
end
