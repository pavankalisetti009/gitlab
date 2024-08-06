# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class CreateDuoEnterpriseService < ::GitlabSubscriptions::Trials::BaseCreateAddOnService
      private

      def apply_trial_service_class
        GitlabSubscriptions::Trials::ApplyDuoEnterpriseService
      end

      def namespaces_eligible_for_trial
        Users::AddOnTrialEligibleNamespacesFinder.new(user, add_on: :duo_enterprise).execute
      end

      override :product_interaction
      def product_interaction
        'duo_enterprise_trial'
      end

      override :tracking_prefix
      def tracking_prefix
        'duo_enterprise'
      end
    end
  end
end
