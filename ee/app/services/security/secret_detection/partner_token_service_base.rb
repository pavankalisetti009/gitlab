# frozen_string_literal: true

module Security
  module SecretDetection
    class PartnerTokenServiceBase
      class << self
        def process_finding_async(findings, project)
          return unless enabled_for_project?(project)

          # Filter to only partner tokens
          partner_findings = findings.select { |finding| partner_token?(finding.token_type) }
          return if partner_findings.empty?

          # Batch schedule with context
          ::Security::SecretDetection::PartnerTokenVerificationWorker.bulk_perform_async_with_contexts(
            partner_findings,
            arguments_proc: ->(finding) { [finding.id, finding.token_type, finding_type] },
            context_proc: ->(_finding) { { project: project } }
          )
        end

        def process_partner_finding(finding)
          return unless enabled_for_project?(finding.project)

          client = PartnerTokensClient.new(finding)
          return unless client.valid_config?
          return if client.rate_limited?

          result = client.verify_token
          save_result(finding, result)
        end

        def save_result(findings, result)
          findings = Array(findings)
          return if findings.empty?
          return unless enabled_for_project?(findings.first.project)

          save_to_database(findings, result.status, result.metadata[:verified_at])
        end

        def partner_token?(token_type)
          PartnerTokens::Registry.partner_for(token_type).present?
        end

        # Abstract methods - override in subclasses
        def finding_type
          raise NotImplementedError, "#{name} must implement .finding_type"
        end

        def token_status_model
          raise NotImplementedError, "#{name} must implement .token_status_model"
        end

        def unique_by_column
          raise NotImplementedError, "#{name} must implement .unique_by_column"
        end

        private

        def enabled_for_project?(project)
          Feature.enabled?(:secret_detection_partner_token_verification, project)
        end

        def save_to_database(findings, status, verified_at)
          attributes = findings.map { |finding| build_attributes(finding, status, verified_at) }

          token_status_model.upsert_all(
            attributes,
            unique_by: unique_by_column,
            update_only: [:status, :last_verified_at]
          )
        end

        def build_attributes(finding, status, verified_at)
          {
            unique_by_column => finding.id,
            project_id: finding.project_id,
            status: status,
            last_verified_at: verified_at
          }
        end
      end
    end
  end
end
