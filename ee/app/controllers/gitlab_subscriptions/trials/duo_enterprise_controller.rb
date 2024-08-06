# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class DuoEnterpriseController < ApplicationController
      include OneTrustCSP
      include GoogleAnalyticsCSP
      include RegistrationsTracking
      include ::Gitlab::Utils::StrongMemoize
      include SafeFormatHelper

      layout 'minimal'

      skip_before_action :set_confirm_warning

      before_action :check_feature_available!
      before_action :check_trial_eligibility!

      feature_category :subscription_management
      urgency :low

      def new
        set_group_name

        render :step_lead
      end

      def create
        @result = GitlabSubscriptions::Trials::CreateDuoEnterpriseService.new(
          step: general_params[:step], lead_params: lead_params, trial_params: trial_params, user: current_user
        ).execute

        if @result.success?
          # lead and trial created

          redirect_to group_settings_gitlab_duo_usage_index_path(@result.payload[:namespace])
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoEnterpriseService::NOT_FOUND
          # namespace not found/not permitted to create
          render_404
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoEnterpriseService::LEAD_FAILED
          set_group_name

          render :step_lead_failed
        else
          # trial creation failed
          general_params[:namespace_id] = @result.payload[:namespace_id]
          set_group_name

          render :step_lead_failed
        end
      end

      private

      def set_group_name
        @group_name = (namespace || eligible_namespaces.first).name
      end

      def eligible_namespaces
        @eligible_namespaces = Users::AddOnTrialEligibleNamespacesFinder
                                 .new(current_user, add_on: :duo_enterprise).execute
      end
      strong_memoize_attr :eligible_namespaces

      def check_feature_available!
        unless ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
            Feature.enabled?(:duo_enterprise_trials, current_user)
          render_404
        end
      end

      def check_trial_eligibility!
        return if eligible_namespaces_exist?

        render_403
      end

      def eligible_namespaces_exist?
        return false if eligible_namespaces.none?

        GitlabSubscriptions::Trials::AddOns.eligible_namespace?(general_params[:namespace_id], eligible_namespaces)
      end

      def namespace
        current_user.owned_groups.find_by_id(general_params[:namespace_id])
      end
      strong_memoize_attr :namespace

      def general_params
        params.permit(:namespace_id, :step)
      end

      def lead_params
        params.permit(
          :company_name, :company_size, :first_name, :last_name, :phone_number,
          :country, :state, :website_url, :glm_content, :glm_source
        ).to_h
      end

      def trial_params
        params.permit(:namespace_id, :trial_entity, :glm_source, :glm_content).to_h
      end
    end
  end
end
