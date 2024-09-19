# frozen_string_literal: true

module Onboarding
  class StatusCreateService
    def initialize(params, session, user, step_url)
      @params = params
      @session = session
      @user = user
      @step_url = step_url
    end

    def execute
      return ServiceResponse.error(message: 'Onboarding is not enabled', payload: payload) unless ::Onboarding.enabled?

      if user.update(user_attributes)
        ServiceResponse.success(payload: payload)
      else
        ServiceResponse.error(message: user.errors.full_messages, payload: payload)
      end
    end

    private

    attr_reader :params, :session, :user, :step_url

    def payload
      # Need to reset here since onboarding_status doesn't live on the user record, but in user_details.
      # Through user is the way we choose to access it, so we'll need to reset/reload.
      { user: user.reset }
    end

    def user_attributes
      {
        onboarding_in_progress: true,
        onboarding_status_step_url: step_url,
        onboarding_status_initial_registration_type: registration_type,
        onboarding_status_registration_type: registration_type
      }
    end

    def registration_type
      if trial_registration_type?
        ::Onboarding::REGISTRATION_TYPE[:trial]
      elsif invited_registration_type?
        ::Onboarding::REGISTRATION_TYPE[:invite]
      elsif subscription_registration_type?
        ::Onboarding::REGISTRATION_TYPE[:subscription]
      elsif free_registration_type?
        ::Onboarding::REGISTRATION_TYPE[:free]
      end
    end

    def invited_registration_type?
      user.members.any?
    end

    def trial_registration_type?
      ::Gitlab::Utils.to_boolean(params[:trial], default: false)
    end

    def subscription_registration_type?
      base_stored_user_location_path == ::Gitlab::Routing.url_helpers.new_subscriptions_path
    end

    def base_stored_user_location_path
      return unless stored_user_location

      URI.parse(stored_user_location).path
    end

    def stored_user_location
      # side effect free look at devise store_location_for(:user)
      session['user_return_to']
    end

    def free_registration_type?
      # This is mainly to give the free registration type declarative meaning in the elseif
      # it is used in.
      true
    end
  end
end
