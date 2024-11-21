# frozen_string_literal: true

# EE:SaaS
module GitlabSubscriptions
  class TrialsController < ApplicationController
    include SafeFormatHelper
    include OneTrustCSP
    include GoogleAnalyticsCSP
    include Gitlab::RackLoadBalancingHelpers

    layout 'minimal'

    skip_before_action :set_confirm_warning
    before_action :authenticate_user!
    before_action :check_feature_available!
    before_action :check_trial_eligibility!
    before_action :eligible_namespaces # needed when namespace_id isn't provided or is 0(new group)

    feature_category :plan_provisioning
    urgency :low

    def new
      if general_params[:step] == GitlabSubscriptions::Trials::CreateService::TRIAL
        render :step_namespace
      else
        render :step_lead
      end
    end

    def create
      @result = GitlabSubscriptions::Trials::CreateService.new(
        step: general_params[:step], lead_params: lead_params, trial_params: trial_params, user: current_user
      ).execute

      if @result.success?
        # lead and trial created
        # We go off the add on here instead of the subscription for the expiration date since
        # in the premium with ultimate trial case the trial_ends_on does not exist on the
        # gitlab_subscription record.
        # We need to stick to an up to date replica or primary db here in order
        # to properly observe the add_on_purchase that CustomersDot created.
        # See https://gitlab.com/gitlab-org/gitlab/-/issues/499720
        load_balancer_stick_request(::Namespace, :namespace, @result.payload[:namespace].id)
        flash[:success] = success_flash_message(
          GitlabSubscriptions::Trials::DuoEnterprise.any_add_on_purchase_for_namespace(@result.payload[:namespace])
        )

        redirect_to trial_success_path(@result.payload[:namespace])
      elsif @result.reason == GitlabSubscriptions::Trials::CreateService::NO_SINGLE_NAMESPACE
        # lead created, but we now need to select namespace and then apply a trial
        redirect_to new_trial_path(@result.payload[:trial_selection_params])
      elsif @result.reason == GitlabSubscriptions::Trials::CreateService::NOT_FOUND
        # namespace not found/not permitted to create
        render_404
      elsif @result.reason == GitlabSubscriptions::Trials::CreateService::LEAD_FAILED
        render :step_lead_failed
      elsif @result.reason == GitlabSubscriptions::Trials::CreateService::NAMESPACE_CREATE_FAILED
        # namespace creation failed
        params[:namespace_id] = @result.payload[:namespace_id] # rubocop:disable Rails/StrongParams -- Not working for assignment

        render :step_namespace_failed
      else
        # trial creation failed
        params[:namespace_id] = @result.payload[:namespace_id] # rubocop:disable Rails/StrongParams -- Not working for assignment

        render :trial_failed
      end
    end

    private

    def trial_success_path(namespace)
      if discover_group_security_flow?
        group_security_dashboard_path(namespace)
      else
        group_settings_gitlab_duo_path(namespace)
      end
    end

    def authenticate_user!
      return if current_user

      redirect_to(
        new_trial_registration_path(::Onboarding::StatusPresenter.glm_tracking_params(params)), # rubocop:disable Rails/StrongParams -- method performs strong params
        alert: I18n.t('devise.failure.unauthenticated')
      )
    end

    def general_params
      params.permit(:step)
    end

    def lead_params
      params.permit(
        *::Onboarding::StatusPresenter::GLM_PARAMS,
        :company_name, :company_size, :first_name, :last_name, :phone_number,
        :country, :state, :website_url
      ).to_h
    end

    def trial_params
      params.permit(*::Onboarding::StatusPresenter::GLM_PARAMS, :new_group_name, :namespace_id, :trial_entity)
      .with_defaults(organization_id: Current.organization_id).to_h
    end

    def eligible_namespaces
      @eligible_namespaces = Namespaces::TrialEligibleFinder.new(user: current_user).execute
    end

    def discover_group_security_flow?
      %w[discover-group-security discover-project-security].include?(trial_params[:glm_content])
    end

    def check_feature_available!
      render_404 unless ::Gitlab::Saas.feature_available?(:subscriptions_trials)
    end

    def check_trial_eligibility!
      return unless should_check_eligibility?
      return if eligible_for_trial?

      render 'gitlab_subscriptions/trials/duo/access_denied', status: :forbidden
    end

    def should_check_eligibility?
      namespace_id = trial_params[:namespace_id]
      namespace_id.present? && !GitlabSubscriptions::Trials.creating_group_trigger?(namespace_id)
    end

    def eligible_for_trial?
      GitlabSubscriptions::Trials.eligible_namespace?(trial_params[:namespace_id], eligible_namespaces)
    end

    def success_flash_message(add_on_purchase)
      if discover_group_security_flow?
        s_("BillingPlans|Congratulations, your free trial is activated.")
      else
        safe_format(
          s_(
            "BillingPlans|You have successfully started an Ultimate and GitLab Duo Enterprise trial that will " \
              "expire on %{exp_date}. " \
              "To give members access to new GitLab Duo Enterprise features, " \
              "%{assign_link_start}assign them%{assign_link_end} to GitLab Duo Enterprise seats."
          ),
          tag_pair(
            helpers.link_to(
              '', help_page_path('subscriptions/subscription-add-ons.md', anchor: 'assign-gitlab-duo-seats'),
              target: '_blank', rel: 'noopener noreferrer'
            ),
            :assign_link_start, :assign_link_end
          ),
          exp_date: l(add_on_purchase.expires_on.to_date, format: :long)
        )
      end
    end
  end
end

GitlabSubscriptions::TrialsController.prepend_mod
