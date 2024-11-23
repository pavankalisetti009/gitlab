# frozen_string_literal: true

module Namespaces
  class TrialEligibleFinder
    def initialize(params = {})
      @params = params
    end

    def execute
      initial_scope.not_duo_enterprise_or_no_add_on.no_active_duo_pro_trial
    end

    private

    attr_reader :params

    def initial_scope
      if params[:user] && params[:namespace]
        raise ArgumentError, 'Only User or Namespace can be provided, not both'
      elsif params[:user]
        params[:user]
          .owned_groups
          .in_specific_plans([no_subscription_plan_name, *::Plan::PLANS_ELIGIBLE_FOR_TRIAL])
          .ordered_by_name
      elsif params[:namespace]
        Namespace.id_in(params[:namespace])
      else
        raise ArgumentError, 'User or Namespace must be provided'
      end
    end

    def no_subscription_plan_name
      # Subscriptions aren't created until needed/looked at
      nil
    end
  end
end
