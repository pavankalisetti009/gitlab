# frozen_string_literal: true

module AuditEvents
  class UnregisterRunnerAuditEventService < RunnerAuditEventService
    def token_field
      :runner_authentication_token
    end

    def message
      return "Unregistered #{runner_type} CI runner, never contacted" if runner.contacted_at.nil?

      "Unregistered #{runner_type} CI runner, last contacted #{runner.contacted_at}"
    end
  end
end
