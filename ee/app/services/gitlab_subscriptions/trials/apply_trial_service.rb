# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class ApplyTrialService < BaseApplyTrialService
      def valid_to_generate_trial?
        namespace.present? && !namespace.trial?
      end

      private

      def execute_trial_request
        if Feature.enabled?(:duo_enterprise_trials_registration, Feature.current_request)
          trial_user_information.merge!(with_add_on: true, add_on_name: 'duo_enterprise')
        end

        client.generate_trial(uid: uid, trial_user: trial_user_information)
      end

      def after_success_hook
        ::Onboarding::ProgressService.new(namespace).execute(action: :trial_started)
      end
    end
  end
end
