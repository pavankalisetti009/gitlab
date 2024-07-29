# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class ApplyDuoProService < ::GitlabSubscriptions::Trials::BaseApplyTrialService
      extend ::Gitlab::Utils::Override

      # TODO: remove with duo_enterprise_trials cleanup
      override :initialize
      def initialize(user:, uid:, trial_user_information:)
        super(uid: uid, trial_user_information: trial_user_information)

        @user = user
      end

      def valid_to_generate_trial?
        namespace.present? && GitlabSubscriptions::DuoPro.namespace_eligible?(namespace, @user) &&
          GitlabSubscriptions::DuoPro.no_add_on_purchase_for_namespace?(namespace)
      end

      private

      def execute_trial_request
        client.generate_addon_trial(uid: uid, trial_user: trial_user_information)
      end
    end
  end
end
