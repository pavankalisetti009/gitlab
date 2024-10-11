# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class DuoEnterpriseController < ApplicationController
      include GitlabSubscriptions::Trials::DuoCommon

      feature_category :subscription_management
      urgency :low

      def new
        if general_params[:step] == GitlabSubscriptions::Trials::CreateDuoEnterpriseService::TRIAL
          track_event('render_duo_enterprise_trial_page')

          render :step_namespace
        else
          set_group_name
          track_event('render_duo_enterprise_lead_page')

          render :step_lead
        end
      end

      def create
        @result = GitlabSubscriptions::Trials::CreateDuoEnterpriseService.new(
          step: general_params[:step], lead_params: lead_params, trial_params: trial_params, user: current_user
        ).execute

        if @result.success?
          # lead and trial created
          flash[:success] = success_flash_message

          redirect_to group_settings_gitlab_duo_seat_utilization_index_path(@result.payload[:namespace])
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoEnterpriseService::NO_SINGLE_NAMESPACE
          # lead created, but we now need to select namespace and then apply a trial
          redirect_to new_trials_duo_enterprise_path(@result.payload[:trial_selection_params])
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoEnterpriseService::NOT_FOUND
          # namespace not found/not permitted to create
          render_404
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoEnterpriseService::LEAD_FAILED
          set_group_name

          render :step_lead_failed
        else
          # trial creation failed
          params[:namespace_id] = @result.payload[:namespace_id] # rubocop:disable Rails/StrongParams -- Not working for assignment

          render :trial_failed
        end
      end

      private

      def set_group_name
        return unless namespace || GitlabSubscriptions::Trials.single_eligible_namespace?(eligible_namespaces)

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

      def track_event(action)
        Gitlab::InternalEvents
          .track_event(action, user: current_user, namespace: namespace || eligible_namespaces.first)
      end

      def trial_params
        params.permit(*::Onboarding::Status::GLM_PARAMS, :namespace_id).to_h
      end

      def success_flash_message
        s_(
          "DuoEnterpriseTrial|You have successfully created a trial subscription from GitLab Duo Enterprise. " \
            "To get started, enable the GitLab Duo Enterprise add-on for team members on this page by turning on " \
            "the toggle for each team member. The subscription may take a minute to sync, so refresh " \
            "the page if it's not visible yet."
        )
      end
    end
  end
end
