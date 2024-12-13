# frozen_string_literal: true

module Users
  module ServiceAccounts
    class CreateService < BaseService
      include Gitlab::Utils::StrongMemoize

      attr_accessor :current_user, :params

      def initialize(current_user, params = {})
        @current_user = current_user
        @params = params.dup
      end

      def execute
        return error(error_messages[:no_permission], :forbidden) unless can_create_service_account?

        return error(error_messages[:no_seats], :forbidden) unless ultimate? || seats_available?

        create_user
      end

      private

      def username_and_email_generator
        Gitlab::Utils::UsernameAndEmailGenerator.new(
          username_prefix: username_prefix,
          email_domain: "noreply.#{Gitlab.config.gitlab.host}"
        )
      end
      strong_memoize_attr :username_and_email_generator

      def username_prefix
        'service_account'
      end

      def can_create_service_account?
        can?(current_user, :admin_service_accounts)
      end

      def create_user
        ::Users::CreateService.new(current_user, default_user_params).execute
      end

      def default_user_params
        {
          name: name,
          email: email,
          username: username,
          user_type: :service_account,
          external: true,
          skip_confirmation: true, # Bot users should always have their emails confirmed.
          organization_id: params[:organization_id],
          avatar: params[:avatar].presence
        }
      end

      def error_messages
        {
          no_permission: s_('ServiceAccount|User does not have permission to create a service account.'),
          no_seats: s_('ServiceAccount|No more seats are available to create Service Account User')
        }
      end

      def email
        username_and_email_generator.email
      end

      def username
        params[:username] || username_and_email_generator.username
      end

      def name
        params[:name] || 'Service account user'
      end

      def error(message, reason)
        ServiceResponse.error(message: message, reason: reason)
      end

      def ultimate?
        License.current.ultimate?
      end

      def seats_available?
        return true if ultimate?

        User.service_account.count < License.current.restricted_user_count.to_i
      end
    end
  end
end
