# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class CreateDuoProService < ::GitlabSubscriptions::Trials::BaseCreateAddOnService
      private

      def apply_trial_service_class
        GitlabSubscriptions::Trials::ApplyDuoProService
      end

      def namespaces_eligible_for_trial
        Users::AddOnTrialEligibleNamespacesFinder.new(user, add_on: :duo_pro).execute
      end

      override :product_interaction
      def product_interaction
        'duo_pro_trial'
      end

      override :tracking_prefix
      def tracking_prefix
        'duo_pro'
      end

      override :apply_trial_params
      def apply_trial_params
        # TODO: remove with duo_enterprise_trials cleanup
        super.merge(user: user)
      end
    end
  end
end
