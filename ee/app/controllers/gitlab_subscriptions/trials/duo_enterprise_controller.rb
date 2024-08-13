# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class DuoEnterpriseController < ApplicationController
      include OneTrustCSP
      include GoogleAnalyticsCSP
      include RegistrationsTracking
      include ::Gitlab::Utils::StrongMemoize
      include SafeFormatHelper
      include ProductAnalyticsTracking

      layout 'minimal'

      skip_before_action :set_confirm_warning

      before_action :check_feature_available!
      before_action :check_trial_eligibility!

      feature_category :subscription_management
      urgency :low

      track_internal_event :new, name: 'render_duo_enterprise_lead_page'

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
          flash[:success] = success_flash_message

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

      def tracking_namespace_source
        namespace || eligible_namespaces.first
      end

      def tracking_project_source
        nil
      end

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

      def success_flash_message
        assign_doc_url = helpers.help_page_path(
          'subscriptions/subscription-add-ons', anchor: 'assign-gitlab-duo-pro-seats'
        )
        assign_link = helpers.link_to('', assign_doc_url, target: '_blank', rel: 'noopener noreferrer')
        assign_link_pair = tag_pair(assign_link, :assign_link_start, :assign_link_end)
        safe_format(
          s_(
            'DuoEnterpriseTrial|Congratulations, your free GitLab Duo Enterprise trial is activated and will ' \
              'expire on %{exp_date}. The new license might take a minute to show on the page. ' \
              'To give members access to new GitLab Duo Enterprise features, ' \
              '%{assign_link_start}assign them%{assign_link_end} to GitLab Duo Enterprise seats.'
          ),
          assign_link_pair,
          exp_date: GitlabSubscriptions::Trials::AddOns::DURATION.from_now.strftime('%Y-%m-%d')
        )
      end
    end
  end
end
