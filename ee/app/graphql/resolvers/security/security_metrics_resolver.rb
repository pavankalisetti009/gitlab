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

      def resolve(**args)
        return unless Ability.allowed?(current_user, :read_security_resource, object)

        if object.is_a?(Project)
          return if Feature.disabled?(:project_security_dashboard_new, object) &&
            Feature.disabled?(:new_security_dashboard_vulnerabilities_per_severity, object)
        elsif object.is_a?(Group)
          return if Feature.disabled?(:group_security_dashboard_new, object) &&
            Feature.disabled?(:new_security_dashboard_vulnerabilities_per_severity, object)
        else
          return
        end

        context[:project_id] = args[:project_id] if args[:project_id].present? && object.is_a?(Group)
        context[:report_type] = args[:report_type] if args[:report_type].present?

        object
      end
    end
  end
end
