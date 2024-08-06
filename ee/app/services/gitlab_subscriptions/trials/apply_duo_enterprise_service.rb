# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class ApplyDuoEnterpriseService < ::GitlabSubscriptions::Trials::BaseApplyTrialService
      def valid_to_generate_trial?
        namespace.present? && GitlabSubscriptions::DuoEnterprise.namespace_eligible?(namespace)
      end

      private

      def execute_trial_request
        client.generate_addon_trial(uid: uid, trial_user: trial_user_information)
      end
    end
  end
end
