# frozen_string_literal: true

module Registrations
  class TrialWelcomeController < ApplicationController
    include ::Onboarding::SetRedirect
    include OneTrustCSP
    include GoogleAnalyticsCSP
    include GoogleSyndicationCSP
    include BizibleCSP

    before_action :verify_onboarding_enabled!
    before_action :enable_dark_mode

    feature_category :onboarding
    urgency :low

    layout 'minimal'

    def new
      experiment(:lightweight_trial_registration_redesign,
        actor: current_user).track(:render_welcome)

      render GitlabSubscriptions::Trials::Welcome::TrialFormComponent.new(user: current_user,
        params: params.permit(*::Onboarding::StatusPresenter::GLM_PARAMS))
    end

    def create
      result = GitlabSubscriptions::Trials::WelcomeCreateService.new(params: create_params,
        user: current_user, **progress_params).execute

      if result.success?
        namespace = result.payload[:namespace]

        experiment(:lightweight_trial_registration_redesign, actor: current_user).track(
          :completed_group_project_creation, namespace: namespace)

        redirect_to namespace_project_get_started_path(namespace, result.payload[:project])
      elsif result.reason == GitlabSubscriptions::Trials::UltimateCreateService::NOT_FOUND
        render_404
      elsif result.payload[:model_errors].present?
        render GitlabSubscriptions::Trials::Welcome::TrialFormComponent.new(user: current_user,
          params: resubmit_params(result))
      else
        render GitlabSubscriptions::Trials::Welcome::ResubmitComponent.new(
          hidden_fields: result.payload,
          submit_path: users_sign_up_trial_welcome_path(**glm_params)
        ).with_content(result.message)
      end
    end

    private

    def enable_dark_mode
      @html_class = 'gl-dark'
    end

    def resubmit_params(result)
      { namespace_id: result.payload[:namespace_id],
        errors: result.payload[:model_errors] }.merge(create_params).to_h.symbolize_keys
    end

    def create_params
      params.permit(
        *::Onboarding::StatusPresenter::GLM_PARAMS,
        :group_name, :project_name, :company_name, :first_name, :last_name, :country, :state
      ).with_defaults(organization_id: Current.organization.id)
    end

    def progress_params
      progress = params.permit(:namespace_id, :project_id, :lead_created)
      progress[:lead_created] = !!ActiveModel::Type::Boolean.new.cast(progress[:lead_created])
      progress.to_h.symbolize_keys
    end

    def glm_params
      params.permit(*::Onboarding::StatusPresenter::GLM_PARAMS).slice(*::Onboarding::StatusPresenter::GLM_PARAMS)
    end
  end
end
