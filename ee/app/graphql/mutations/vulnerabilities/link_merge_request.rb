# frozen_string_literal: true

module Mutations
  module Vulnerabilities
    class LinkMergeRequest < BaseMutation
      graphql_name 'VulnerabilityLinkMergeRequest'
      description 'Link a merge request to a vulnerability'

      def self.authorization_scopes
        [:api, :ai_workflows]
      end

      authorize :admin_vulnerability_merge_request_link

      argument :vulnerability_id, ::Types::GlobalIDType[::Vulnerability],
        required: true, description: 'ID of the vulnerability.'

      argument :merge_request_id, ::Types::GlobalIDType[::MergeRequest],
        required: true, description: 'ID of the merge request.'

      argument :readiness_score, GraphQL::Types::Float,
        required: false,
        description: 'Confidence rating representing the estimated accuracy of the fix in the AI generated ' \
          'merge request. Decimal value between 0 and 1, with 1 being the highest.'

      field :vulnerability, Types::VulnerabilityType,
        null: true, description: 'Updated vulnerability.',
        scopes: [:api, :ai_workflows]

      def resolve(vulnerability_id:, merge_request_id:, readiness_score: nil)
        vulnerability = authorized_find!(id: vulnerability_id)
        merge_request = Gitlab::Graphql::Lazy.force(GitlabSchema.find_by_gid(merge_request_id))

        unless can_read_merge_request?(merge_request)
          return { vulnerability: nil,
                   errors: ['The merge request does not exist or you do not have permission to view it.'] }
        end

        result = ::VulnerabilityMergeRequestLinks::CreateService.new(
          project: vulnerability.project,
          current_user: current_user,
          params: {
            vulnerability: vulnerability,
            merge_request: merge_request,
            readiness_score: readiness_score
          }
        ).execute

        if result.success?
          { vulnerability: vulnerability, errors: [] }
        else
          { vulnerability: nil, errors: result.payload[:errors] }
        end
      end

      def can_read_merge_request?(merge_request)
        merge_request.present? && Ability.allowed?(current_user, :read_merge_request, merge_request)
      end
    end
  end
end
