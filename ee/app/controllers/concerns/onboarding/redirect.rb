# frozen_string_literal: true

module Onboarding
  module Redirect
    extend ActiveSupport::Concern

    included do
      with_options if: :user_onboarding? do
        # We will handle the 2fa setup after onboarding if it is needed
        skip_before_action :check_two_factor_requirement
        before_action :onboarding_redirect
      end
    end

    private

    def onboarding_redirect
      return unless valid_for_onboarding_redirect?(current_user.onboarding_status_step_url)

      redirect_to current_user.onboarding_status_step_url
    end

    def user_onboarding?
      ::Onboarding.user_onboarding_in_progress?(current_user)
    end

    def valid_for_onboarding_redirect?(path)
      return false unless path.present? && request.get?
      return false if welcome_and_already_completed?

      gitlab_url = Gitlab.config.gitlab.url
      normalized_path = path.sub(/\A#{Regexp.escape(gitlab_url)}/, '')

      normalized_path != request.fullpath && valid_referer?(path)
    end

    def welcome_and_already_completed?
      return false if ::Feature.disabled?(:stop_welcome_redirection, current_user)

      step_url = current_user.onboarding_status_step_url
      return false unless step_url.present?

      if step_url.include?(users_sign_up_welcome_path) && ::Onboarding.completed_welcome_step?(current_user)
        ::Gitlab::ErrorTracking.track_exception(
          ::Onboarding::StepUrlError.new('User has already completed welcome step'),
          onboarding_status: current_user.onboarding_status.to_json
        )

        Onboarding::FinishService.new(current_user).execute
        return true
      end

      false
    end

    def valid_referer?(path)
      # do not redirect additional requests on the page
      # with current page as a referer
      request.referer.blank? || path.exclude?(URI(request.referer).path)
    end
  end
end
