# frozen_string_literal: true

module Resolvers
  module SecretsManagement
    class GroupSecretsManagerResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource
      include ResolvesGroup

      type ::Types::SecretsManagement::GroupSecretsManagerType, null: true

      argument :group_path, GraphQL::Types::ID,
        required: true,
        description: 'Group of the secrets manager.'

      authorize :read_group_secrets_manager

      def resolve(group_path:)
        group = authorized_find!(group_path: group_path)
        group.secrets_manager
      end

      private

      def find_object(group_path:)
        resolve_group(full_path: group_path)
      end
    end
  end
end
