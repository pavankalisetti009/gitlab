# frozen_string_literal: true

#
# This resolver is a WIP and part of ongoing work for the Security Dashboard Project (https://gitlab.com/groups/gitlab-org/-/epics/16517)
#
module Resolvers
  module Security
    class SecurityMetricsResolver < BaseResolver
      include Gitlab::Utils::StrongMemoize
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::Security::SecurityMetricsType, null: true

      argument :project_id, [GraphQL::Types::ID],
        required: false,
        description: 'Filter by project IDs in a group. This argument is ignored when we are querying for a project.'

      argument :report_type, [Types::VulnerabilityReportTypeEnum],
        required: false,
        description: 'Filter by report types.'

      argument :security_attributes_filters, [Types::Security::AttributeFilterInputType],
        required: false,
        experiment: { milestone: '18.8' },
        description: 'Filter by security attributes.'

      def resolve(**args)
        return unless Ability.allowed?(current_user, :read_security_resource, object)

        return unless object.is_a?(Project) || object.is_a?(Group)

        context[:project_id] = args[:project_id] if args[:project_id].present? && object.is_a?(Group)
        context[:report_type] = args[:report_type] if args[:report_type].present?

        object
      end
    end
  end
end
