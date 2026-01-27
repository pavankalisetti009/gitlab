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
        render_404 unless ::Feature.enabled?(:automatic_self_managed_trial_activation, :instance)
      end
    end
  end
end
