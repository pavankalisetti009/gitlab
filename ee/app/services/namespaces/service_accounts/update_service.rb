# frozen_string_literal: true

module Namespaces
  module ServiceAccounts
    class UpdateService
      attr_reader :current_user, :user, :params

      ALLOWED_PARAMS = [:username, :name].freeze

      def initialize(current_user, user, params = {})
        @current_user = current_user
        @user = user
        @params = params.slice(*ALLOWED_PARAMS)
      end

      def execute
        return error(_('User is not a service account'), :bad_request) unless user.service_account?

        unless can_update_service_account?
          return error(
            s_('ServiceAccount|You are not authorized to update service accounts in this namespace.'),
            :forbidden
          )
        end

        user_update = update_user

        if user_update[:status] == :success
          success
        else
          error(user_update[:message], :bad_request)
        end
      end

      private

      def can_update_service_account?
        Ability.allowed?(current_user, :admin_service_accounts, user.provisioned_by_group)
      end

      def update_user
        Users::UpdateService.new(current_user, update_params.merge(user: user, force_name_change: true)).execute
      end

      def update_params
        params
      end

      def error(message, reason)
        ServiceResponse.error(message: message, reason: reason)
      end

      def success
        ServiceResponse.success(message: _('Service account was successfully updated.'), payload: { user: user })
      end
    end
  end
end
