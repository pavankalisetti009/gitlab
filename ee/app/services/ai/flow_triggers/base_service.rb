# frozen_string_literal: true

module Ai
  module FlowTriggers
    class BaseService
      attr_reader :project, :current_user, :resource, :flow_trigger

      def user_is_authorized_to_service_account?(params)
        service_account = User.find(params[:user_id])
        return false unless service_account.service_account?

        group = service_account.provisioned_by_group

        return false unless group
        return false unless group.root_ancestor.id == project.root_ancestor.id

        Ability.allowed?(current_user, :admin_service_accounts, group)
      end
    end
  end
end
