# frozen_string_literal: true

module Resolvers
  module Vulnerabilities
    class FindingTokenStatusResolver < BaseResolver
      type Types::Vulnerabilities::FindingTokenStatusType, null: true

      alias_method :vulnerability, :object

      def resolve
        return if Feature.disabled?(:validity_checks, vulnerability.project)
        return unless vulnerability.finding

        BatchLoader::GraphQL.for(vulnerability.finding.id).batch do |finding_ids, loader|
          ::Vulnerabilities::FindingTokenStatus
            .with_vulnerability_occurrence_ids(finding_ids)
            .find_each do |token_status|
              loader.call(token_status.vulnerability_occurrence_id, token_status)
            end
        end
      end
    end
  end
end
