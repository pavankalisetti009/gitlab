# frozen_string_literal: true

module Mutations
  module Security
    class ProjectSecurityExclusionDelete < BaseMutation
      graphql_name 'ProjectSecurityExclusionDelete'

      authorize :manage_project_security_exclusions

      argument :id, ::Types::GlobalIDType[::Security::ProjectSecurityExclusion],
        required: true,
        description: 'Global ID of the exclusion to be deleted.'

      def resolve(id:)
        project_security_exclusion = authorized_find!(id: id)

        unless project_security_exclusion.project.licensed_feature_available?(:security_exclusions)
          raise_resource_not_available_error!
        end

        if project_security_exclusion.destroy
          { errors: [] }
        else
          { errors: errors_on_object(project_security_exclusion) }
        end
      end

      def find_object(id:)
        GitlabSchema.object_from_id(id)
      end
    end
  end
end
