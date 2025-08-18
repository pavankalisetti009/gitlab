# frozen_string_literal: true

class UserBillingPricingInformationExperiment < ApplicationExperiment
  control
  variant(:candidate)

  exclude :paid_user?

  private

  def control_behavior; end

  def candidate_behavior; end

  def paid_user?
    user = context.actor

    user.owned_groups.free_or_trial.empty?
  end
end
