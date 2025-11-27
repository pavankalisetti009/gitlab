# frozen_string_literal: true

module Types
  module SecretsManagement
    module SecretsPermissionInterface
      extend ActiveSupport::Concern

      included do
        field :principal,
          Types::SecretsManagement::Permissions::PrincipalType,
          null: false,
          description: 'Who is provided access to. For eg: User/Role/MemberRole/Group.'

        field :permissions,
          type: GraphQL::Types::String,
          null: false,
          description: "Permissions to be provided. ['create', 'update', 'read', 'delete']."

        field :granted_by,
          Types::UserType,
          null: true,
          description: "User who created the Secret Permission."

        field :expired_at,
          type: GraphQL::Types::ISO8601Date,
          null: true,
          description: "Expiration date for Secret Permission (optional)."
      end

      def granted_by
        BatchLoader::GraphQL.for(object.granted_by).batch do |user_ids, loader|
          users = ::UsersFinder.new(current_user, ids: user_ids).execute
          users.each { |user| loader.call(user.id, user) }
        end
      end

      def principal
        {
          id: object.principal_id.to_s,
          type: object.principal_type.to_s,
          resource_id: object.resource.id.to_s
        }
      end
    end
  end
end
