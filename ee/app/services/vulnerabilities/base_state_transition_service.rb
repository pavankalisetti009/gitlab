# frozen_string_literal: true

module Vulnerabilities
  class BaseStateTransitionService < BaseService
    def initialize(user, vulnerability, comment)
      super(user, vulnerability)
      @comment = comment
    end

    def execute
      raise Gitlab::Access::AccessDeniedError unless authorized?

      if can_transition?
        SecApplicationRecord.transaction do
          Vulnerabilities::StateTransition.create!(
            vulnerability: @vulnerability,
            from_state: @vulnerability.state,
            to_state: to_state,
            author: @user,
            comment: @comment
          )

          update_vulnerability!
          update_vulnerability_reads!
          update_risk_score
        end
      end

      @vulnerability
    end

    def update_vulnerability_reads!
      # the dismiss_service does not inherit from the
      # BaseStateTransitionService so this check is a
      # redundant safety check
      return if to_state == :dismissed

      Vulnerabilities::Read.by_vulnerabilities(@vulnerability).update(dismissal_reason: nil)
    end

    def update_risk_score
      return unless Vulnerability.active_states.include?(to_state.to_s)

      Vulnerabilities::Findings::RiskScoreCalculationService.calculate_for(@vulnerability)
    end
  end
end
