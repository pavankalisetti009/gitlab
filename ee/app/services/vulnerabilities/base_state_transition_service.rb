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
          update_risk_score

          # the dismiss_service does not inherit from the
          # BaseStateTransitionService so this check is a
          # redundant safety check
          if to_state != :dismissed
            Vulnerabilities::Reads::UpsertService.new(@vulnerability,
              { state: to_state, dismissal_reason: nil },
              projects: @project
            ).execute
          end
        end
      end

      @vulnerability
    end

    def update_risk_score
      return unless Vulnerability.active_states.include?(to_state.to_s)

      Vulnerabilities::Findings::RiskScoreCalculationService.calculate_for(@vulnerability)
    end
  end
end
