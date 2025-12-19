# frozen_string_literal: true

module Ci
  module RunnerControllers
    class RevokeTokenService
      attr_reader :token, :current_user

      def initialize(token:, current_user:)
        @token = token
        @current_user = current_user
      end

      def execute
        return error_no_permissions unless current_user.can_admin_all_resources?

        if token.revoke!
          ServiceResponse.success
        else
          ServiceResponse.error(message: token.errors.full_messages)
        end
      end

      private

      def error_no_permissions
        ServiceResponse.error(message: 'Administrator permission is required to revoke this token')
      end
    end
  end
end
