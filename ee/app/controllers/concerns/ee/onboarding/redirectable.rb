# frozen_string_literal: true

module EE
  module Onboarding
    module Redirectable
      extend ::Gitlab::Utils::Override

      private

      def onboarding_first_step_path
        return unless ::Onboarding.enabled?

        users_sign_up_welcome_path(onboarding_params)
      end

      def onboarding_params
        ::Onboarding::Status.glm_tracking_params(params) # rubocop:disable Rails/StrongParams -- strong params are used in the method being called
      end

      override :after_sign_up_path
      def after_sign_up_path
        if ::Onboarding.enabled?
          onboarding_first_step_path
        else
          super
        end
      end
    end
  end
end
