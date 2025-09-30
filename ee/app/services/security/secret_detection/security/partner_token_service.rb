# frozen_string_literal: true

module Security
  module SecretDetection
    module Security
      class PartnerTokenService
        def save_result(finding, result)
          save_to_database(finding, result.status, result.metadata[:verified_at])
        end

        private

        def save_to_database(finding, status, verified_at)
          attributes = {
            security_finding_id: finding.id,
            project_id: finding.project.id,
            status: status,
            last_verified_at: verified_at
          }

          ::Security::FindingTokenStatus.upsert(
            attributes,
            unique_by: :security_finding_id,
            update_only: [:status, :last_verified_at]
          )
        end
      end
    end
  end
end
