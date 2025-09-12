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

      def user_is_authorized_to_service_account?(service_account)
        return false unless service_account.service_account?

        group = service_account.provisioned_by_group

        return false unless group
        return false unless group.root_ancestor.id == project.root_ancestor.id

        Ability.allowed?(current_user, :admin_service_accounts, group)
      end

      def enforce_composite_identity!(service_account)
        return unless Feature.enabled?(:duo_workflow_use_composite_identity, current_user)

        service_account.update!(composite_identity_enforced: true)
      end
    end
  end
end
