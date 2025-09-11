# frozen_string_literal: true

class DefaultPinnedNavItemsExperiment < ApplicationExperiment
  control
  variant(:candidate)

  exclude :non_new_trial_registrations
  exclude :specific_onboarding_statuses

  EXCLUDED_REGISTRATION_OBJECTIVES = [
    ::UserDetail.onboarding_status_registration_objectives['basics'],
    ::UserDetail.onboarding_status_registration_objectives['other']
  ].compact.freeze

  EXCLUDED_ROLES = [
    ::UserDetail.onboarding_status_roles['security_analyst'],
    ::UserDetail.onboarding_status_roles['data_analyst'],
    ::UserDetail.onboarding_status_roles['product_manager'],
    ::UserDetail.onboarding_status_roles['product_designer'],
    ::UserDetail.onboarding_status_roles['other']
  ].compact.freeze

  private

  def control_behavior; end
  def candidate_behavior; end

  def actor
    user_or_actor
  end

  def non_new_trial_registrations
    return true unless actor # not created user yet
    return true if actor.is_a? String # not logged in yet - cookie signature

    actor.onboarding_status_registration_type != 'trial'
  end

  def specific_onboarding_statuses
    EXCLUDED_ROLES.include?(actor.onboarding_status_role) ||
      EXCLUDED_REGISTRATION_OBJECTIVES.include?(actor.onboarding_status_registration_objective)
  end
end
