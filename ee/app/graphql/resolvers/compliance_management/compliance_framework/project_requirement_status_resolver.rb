# frozen_string_literal: true

module Resolvers
  module ComplianceManagement
    module ComplianceFramework
      class ProjectRequirementStatusResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        alias_method :project, :object

        type ::Types::ComplianceManagement::ComplianceFramework::ProjectRequirementStatusType.connection_type,
          null: true
        description 'Compliance requirement statuses for a project.'

        authorize :read_compliance_adherence_report
        authorizes_object!

        def resolve
          requirement_status_records = ::ComplianceManagement::ComplianceFramework::ProjectRequirementStatusFinder.new(
            project.group,
            current_user,
            { project_id: project.id }
          ).execute

          offset_pagination(requirement_status_records)
        end
      end
    end
  end
end
