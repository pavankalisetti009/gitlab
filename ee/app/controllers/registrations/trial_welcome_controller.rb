# frozen_string_literal: true

module Registrations
  class TrialWelcomeController < ApplicationController
    include ::Onboarding::SetRedirect

    before_action :verify_onboarding_enabled!

    feature_category :onboarding
    urgency :low

    def new
      render GitlabSubscriptions::Trials::Welcome::TrialFormComponent.new(user: current_user,
        params: params.permit(*::Onboarding::StatusPresenter::GLM_PARAMS))
    end
  end
end
