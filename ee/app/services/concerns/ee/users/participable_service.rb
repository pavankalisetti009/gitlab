# frozen_string_literal: true

module EE
  module Users
    module ParticipableService
      extend ::Gitlab::Utils::Override

      override :user_as_hash
      def user_as_hash(user)
        super.merge(user_disabled_fields(user))
      end

      override :org_user_detail_as_hash
      def org_user_detail_as_hash(detail)
        super.merge(user_disabled_fields(detail.user))
      end

      def user_disabled_fields(user)
        disabled = user_disabled?(user)

        if disabled
          return {
            disabled: true,
            disabled_reason: "Unavailable - no credits"
          }
        end

        {
          disabled: false,
          disabled_reason: ""
        }
      end

      private

      def user_disabled?(user)
        return false unless user.service_account? && user.composite_identity_enforced?

        ::Ai::UsageQuotaService.new(ai_feature: :duo_agent_platform, user: user).execute.error?
      end
    end
  end
end
