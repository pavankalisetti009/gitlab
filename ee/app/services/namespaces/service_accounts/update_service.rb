# frozen_string_literal: true

module Namespaces
  module ServiceAccounts
    class UpdateService < ::Users::ServiceAccounts::UpdateService
      extend ::Gitlab::Utils::Override

      attr_reader :group_id, :project_id

      def initialize(current_user, user, params = {})
        super
        @group_id = params[:group_id]
        @project_id = params[:project_id]
      end

      override :execute
      def execute
        if project_level?
          return error(error_messages[:project_not_found], :not_found) unless project.present?

          unless project.id == user.provisioned_by_project_id
            return error(error_messages[:invalid_project_id],
              :bad_request)
          end
        else
          return error(error_messages[:group_not_found], :not_found) unless group.present?
          return error(error_messages[:invalid_group_id], :bad_request) unless group.id == user.provisioned_by_group_id
        end

        super
      end

      private

      # Determines if this is a project-level service account update
      def project_level?
        @project_id.present?
      end

      override :can_update_service_account?
      def can_update_service_account?
        if project_level?
          Ability.allowed?(current_user, :admin_service_accounts, user.provisioned_by_project)
        else
          Ability.allowed?(current_user, :admin_service_accounts, user.provisioned_by_group)
        end
      end

      def group
        @_group ||= ::Group.find_by_id(@group_id)
      end

      def project
        @_project ||= ::Project.find_by_id(@project_id)
      end

      override :skip_confirmation?
      def skip_confirmation?
        return super if project_level?

        super || group.owner_of_email?(params[:email])
      end

      override :error_messages
      def error_messages
        super.merge(
          no_permission:
            s_('ServiceAccount|You are not authorized to update service accounts in this namespace.'),
          invalid_group_id: s_('ServiceAccount|Group ID provided does not match the service account\'s group ID.'),
          group_not_found: s_('ServiceAccount|Group with the provided ID not found.'),
          invalid_project_id: s_('ServiceAccount|Project ID provided does not match ' \
            'the service account\'s project ID.'),
          project_not_found: s_('ServiceAccount|Project with the provided ID not found.')
        )
      end
    end
  end
end
