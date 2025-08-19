# frozen_string_literal: true

module Security
  class FindingTokenStatusPolicy < BasePolicy
    delegate { @subject.security_finding }

    condition(:validity_checks_ff) { ::Feature.enabled?(:validity_checks, @subject.project) }
    condition(:validity_checks_security_finding_status_ff) do
      ::Feature.enabled?(:validity_checks_security_finding_status, @subject.project)
    end
    condition(:read_vulnerability) { can?(:read_vulnerability, @subject.project) }

    rule { validity_checks_ff & validity_checks_security_finding_status_ff & read_vulnerability }.policy do
      enable :read_finding_token_status
    end
  end
end
