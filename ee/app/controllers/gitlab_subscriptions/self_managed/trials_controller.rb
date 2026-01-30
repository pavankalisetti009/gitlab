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

      def create
        result = GitlabSubscriptions::SelfManaged::CreateTrialService.new(
          params: create_params,
          user: current_user
        ).execute

        if result.success?
          redirect_to admin_subscription_path
        else
          render GitlabSubscriptions::SelfManaged::ResubmitComponent.new(
            hidden_fields: create_params.to_h,
            submit_path: self_managed_trials_path
          ).with_content(result.message)
        end
      end

      private

      def check_feature_available!
        render_404 unless ::Feature.enabled?(:automatic_self_managed_trial_activation, :instance)
      end

      def create_params
        params.permit(
          :first_name, :last_name, :email_address, :company_name,
          :country, :state, :consent_to_marketing
        )
      end
    end
  end
end
