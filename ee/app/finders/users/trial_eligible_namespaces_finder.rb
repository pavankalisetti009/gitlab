# frozen_string_literal: true

module Users
  class TrialEligibleNamespacesFinder
    def initialize(user)
      @user = user
    end

    def execute
      items = user.manageable_namespaces_eligible_for_trial

      filter_eligible_namespaces(items)
    end

    private

    attr_reader :user

    def filter_eligible_namespaces(items)
      items.not_duo_enterprise_or_no_add_on.no_active_duo_pro_trial
    end
  end
end
