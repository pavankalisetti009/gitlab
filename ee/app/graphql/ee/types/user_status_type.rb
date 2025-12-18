# frozen_string_literal: true

module EE
  module Types
    module UserStatusType
      extend ActiveSupport::Concern

      prepended do
        field :disabled_for_duo_usage, GraphQL::Types::Boolean, null: false,
          description: 'Indicates if the user is disabled for assignment in Duo features.'
        field :disabled_for_duo_usage_reason, GraphQL::Types::String, null: true,
          description: 'Reason why the user is disabled for assignment in Duo features.'

        def disabled_for_duo_usage
          user = object.user

          return false unless user.service_account? && user.composite_identity_enforced?

          quota_check.error?
        end

        def disabled_for_duo_usage_reason
          return "" unless disabled_for_duo_usage

          "Unavailable - no credits"
        end

        private

        def quota_check
          @quota_check ||= ::Ai::UsageQuotaService.new(ai_feature: :duo_agent_platform, user: object.user).execute
        end
      end
    end
  end
end
