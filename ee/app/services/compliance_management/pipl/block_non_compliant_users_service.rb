# frozen_string_literal: true

module ComplianceManagement
  module Pipl
    class BlockNonCompliantUsersService
      include ComplianceManagement::Pipl::UserConcern

      def initialize(pipl_user:, blocking_user:)
        @pipl_user = pipl_user
        @blocking_user = blocking_user
      end

      def execute
        result = validate!

        return result if result&.error?

        set_admin_note(user)
        result = ::Users::BlockService.new(blocking_user).execute(user)

        if result[:status] == :success
          ServiceResponse.success
        else
          error_response(result[:message])
        end
      end

      private

      attr_reader :pipl_user, :blocking_user

      delegate :user, to: :pipl_user, private: true

      def validate!
        return error_response("Pipl user record does not exist") unless pipl_user.present?
        return error_response("Blocking user record does not exist") unless blocking_user.present?
        return error_response("Feature 'enforce_pipl_compliance' is disabled") unless enforce_pipl_compliance?
        return error_response("User belongs to a paid group") if belongs_to_paid_group?(user)
        return error_response("Blocking user is not an admin") unless blocking_user.can_admin_all_resources?

        error_response("Pipl block threshold has not been exceeded for user: #{user.id}") unless pipl_user.blockable?
      end

      def error_response(message)
        ServiceResponse.error(message: message)
      end

      def enforce_pipl_compliance?
        Feature.enabled?(:enforce_pipl_compliance, user)
      end

      def set_admin_note(user)
        admin_message = "User was blocked due to the %{days}-day " \
          "PIPL compliance block threshold being reached"
        pipl_blocked_note = format(_(admin_message), days: PiplUser::NOTICE_PERIOD / 1.day)
        user.add_admin_note(pipl_blocked_note)
      end
    end
  end
end
