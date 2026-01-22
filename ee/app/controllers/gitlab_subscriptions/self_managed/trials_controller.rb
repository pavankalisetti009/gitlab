# frozen_string_literal: true

module GitlabSubscriptions
  module SelfManaged
    class TrialsController < ApplicationController
      layout 'minimal'

      before_action :check_feature_available!

      feature_category :acquisition

      def new
        render GitlabSubscriptions::SelfManaged::TrialFormComponent.new(user: current_user)
      end

      def create; end

      private

      def check_feature_available!
        render_404 if ::Gitlab::Saas.feature_available?(:subscriptions_trials) || ::Feature.disabled?(
          :automatic_self_managed_trial_activation, current_user)
      end
    end
  end
end
