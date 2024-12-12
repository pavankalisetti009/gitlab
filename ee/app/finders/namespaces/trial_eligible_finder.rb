# frozen_string_literal: true

module Namespaces
  class TrialEligibleFinder
    def initialize(params = {})
      @params = params
    end

    def execute
      if ::Feature.enabled?(:premium_can_trial_again, ::Feature.current_request)
        filter_by_duo_enterprise_eligibility.ordered_by_name
      else
        original_initial_scope.not_duo_enterprise_or_no_add_on.no_active_duo_pro_trial
      end
    end

    private

    attr_reader :params

    def original_initial_scope
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

    def scope_by_plans(plans)
      if params[:user] && params[:namespace]
        raise ArgumentError, 'Only User or Namespace can be provided, not both'
      elsif params[:user]
        params[:user].owned_groups.in_specific_plans(plans)
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

    def filter_by_duo_enterprise_eligibility
      premium_namespaces = scope_by_plans(::Plan::PREMIUM)

      # Get the subscription history that was created the last time this namespace left
      # the free plan.
      latest_history = GitlabSubscriptions::SubscriptionHistory
                         .latest_updated_history_by_hosted_plan_id(
                           ::Plan.by_name(::Plan::FREE).select(:id), premium_namespaces.select(:id)
                         )

      # Allow premium namespaces to start a new Ultimate + Duo Enterprise trial if:
      # 1. Their last trial was when they were on a free plan
      # 2. They had a Duo Enterprise add-on before upgrading to Premium
      #
      # Rationale:
      # - We assume Duo Enterprise on a free plan was always part of a trial
      # - We don't need to check if the add-on was a trial, as this info is transient
      # - This logic may allow some edge cases (e.g., Ultimate -> Free -> Premium),
      #   but these will be addressed in https://gitlab.com/groups/gitlab-org/-/epics/16169
      #
      # Note: This approach ensures eligibility for another Ultimate + Duo Enterprise trial
      #       for customers who have upgraded from free to premium plans.
      allowing_another_trial =
        premium_namespaces
          .by_subscription_history_for_expired_duo_enterprise_add_on(latest_history)
          .id_not_in(
            GitlabSubscriptions::AddOnPurchase
              .by_add_on_name('code_suggestions')
              .trial
              .active
              .by_namespace(premium_namespaces)
              .select(:namespace_id)
          ).select(:id)

      Namespace.id_in(Namespace.from_union(base_qualifications, allowing_another_trial).select(:id))
    end

    def base_qualifications
      scope_by_plans([no_subscription_plan_name, *::Plan::PLANS_ELIGIBLE_FOR_TRIAL])
        .not_duo_enterprise_or_no_add_on.no_active_duo_pro_trial.select(:id)
    end
  end
end
