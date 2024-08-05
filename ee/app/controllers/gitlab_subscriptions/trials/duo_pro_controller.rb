# frozen_string_literal: true

# EE:SaaS
module GitlabSubscriptions
  module Trials
    class DuoProController < ApplicationController
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
        if params[:step] == GitlabSubscriptions::Trials::CreateDuoProService::TRIAL
          track_event('render_duo_pro_trial_page')

          render :step_namespace
        else
          track_event('render_duo_pro_lead_page')

          render :step_lead
        end
      end

      def create
        @result = GitlabSubscriptions::Trials::CreateDuoProService.new(
          step: params[:step], lead_params: lead_params, trial_params: trial_params, user: current_user
        ).execute

        if @result.success?
          # lead and trial created
          flash[:success] = success_flash_message

          redirect_to group_settings_gitlab_duo_usage_index_path(@result.payload[:namespace])
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoProService::NO_SINGLE_NAMESPACE
          # lead created, but we now need to select namespace and then apply a trial
          redirect_to new_trials_duo_pro_path(@result.payload[:trial_selection_params])
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoProService::NOT_FOUND
          # namespace not found/not permitted to create
          render_404
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoProService::LEAD_FAILED
          render :step_lead_failed
        else
          # trial creation failed
          params[:namespace_id] = @result.payload[:namespace_id]

          render :trial_failed
        end
      end

      private

      def eligible_namespaces
        @eligible_namespaces = Users::AddOnTrialEligibleNamespacesFinder.new(current_user, add_on: :duo_pro).execute
      end
      strong_memoize_attr :eligible_namespaces

      def check_feature_available!
        return if ::Gitlab::Saas.feature_available?(:subscriptions_trials)

        render_404
      end

      def check_trial_eligibility!
        return if eligible_namespaces_exist?

        render :access_denied, layout: 'minimal', status: :forbidden
      end

      def eligible_namespaces_exist?
        return false if eligible_namespaces.none?

        GitlabSubscriptions::Trials::AddOns.eligible_namespace?(params[:namespace_id], eligible_namespaces)
      end

      def namespace
        current_user.owned_groups.find_by_id(params[:namespace_id])
      end
      strong_memoize_attr :namespace

      def track_event(action)
        Gitlab::InternalEvents.track_event(action, user: current_user, namespace: namespace)
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

      def success_flash_message
        assign_doc_url = helpers.help_page_path('subscriptions/subscription-add-ons',
          anchor: 'assign-gitlab-duo-pro-seats')
        assign_link = helpers.link_to('', assign_doc_url, target: '_blank', rel: 'noopener noreferrer')
        assign_link_pair = tag_pair(assign_link, :assign_link_start, :assign_link_end)
        safe_format(
          s_(
            'DuoProTrial|Congratulations, your free GitLab Duo Pro trial is activated and will ' \
            'expire on %{exp_date}. The new license might take a minute to show on the page. ' \
            'To give members access to new GitLab Duo Pro features, ' \
            '%{assign_link_start}assign them%{assign_link_end} to GitLab Duo Pro seats.'
          ),
          assign_link_pair,
          exp_date: GitlabSubscriptions::Trials::AddOns::DURATION.from_now.strftime('%Y-%m-%d')
        )
      end
    end
  end
end
