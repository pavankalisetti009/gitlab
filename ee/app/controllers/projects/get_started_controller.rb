# frozen_string_literal: true

module Projects
  class GetStartedController < Projects::ApplicationController
    include ::Onboarding::SetRedirect

    before_action :verify_onboarding_enabled!
    before_action :authenticate_user!
    before_action :verify_available!

    helper_method :onboarding_progress

    feature_category :onboarding
    urgency :low

    private

    def onboarding_progress
      # We only want to observe first level projects.
      # We do not care about any of their subgroup projects.
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/537653#note_2478488770
      @onboarding_progress ||= ::Onboarding::Progress.find_by_namespace_id!(@project.namespace)
    end

    def verify_available!
      unless ::Feature.enabled?(:learn_gitlab_redesign, @project.namespace) &&
          ::Onboarding::LearnGitlab.available?(project.namespace, current_user)
        access_denied!
      end
    end
  end
end
