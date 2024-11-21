# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class DuoEnterpriseController < ApplicationController
      include GitlabSubscriptions::Trials::DuoCommon
      include Gitlab::RackLoadBalancingHelpers

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
          # We need to stick to an up to date replica or primary db here in order
          # to properly observe the add_on_purchase that CustomersDot created.
          # See https://gitlab.com/gitlab-org/gitlab/-/issues/499720
          load_balancer_stick_request(::Namespace, :namespace, @result.payload[:namespace].id)
          flash[:success] = success_flash_message(
            GitlabSubscriptions::Trials::DuoEnterprise.any_add_on_purchase_for_namespace(@result.payload[:namespace])
          )

          redirect_to group_settings_gitlab_duo_path(@result.payload[:namespace])
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

      def eligible_namespaces
        @eligible_namespaces = Users::AddOnTrialEligibleNamespacesFinder
                                 .new(current_user, add_on: :duo_enterprise).execute
      end
      strong_memoize_attr :eligible_namespaces

      def track_event(action)
        Gitlab::InternalEvents
          .track_event(action, user: current_user, namespace: namespace || eligible_namespaces.first)
      end

      def trial_params
        params.permit(*::Onboarding::StatusPresenter::GLM_PARAMS, :namespace_id).to_h
      end

      def success_flash_message(add_on_purchase)
        safe_format(
          s_(
            'DuoEnterpriseTrial|You have successfully started a Duo Enterprise trial that will ' \
              'expire on %{exp_date}. To give members access to new GitLab Duo Enterprise features, ' \
              '%{assign_link_start}assign them%{assign_link_end} to GitLab Duo Enterprise seats.'
          ),
          success_doc_link,
          exp_date: l(add_on_purchase.expires_on.to_date, format: :long)
        )
      end
    end
  end
end
