# frozen_string_literal: true

module Security
  module SecretDetection
    module Vulnerabilities
      class PartnerTokenService
        def save_result(finding, result)
          save_to_database(finding, result.status, result.metadata[:verified_at])
        end

        private

        def save_to_database(finding, status, verified_at)
          attributes = {
            vulnerability_occurrence_id: finding.id,
            project_id: finding.project_id,
            status: status,
            last_verified_at: verified_at
          }

          ::Vulnerabilities::FindingTokenStatus.upsert(
            attributes,
            unique_by: :vulnerability_occurrence_id,
            update_only: [:status, :last_verified_at]
          )
        end
      end
    end
  end
end
