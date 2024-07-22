# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    module Security
      # rubocop:disable Graphql/AuthorizeTypes -- Authorization will be handled in subscription
      class PolicyProjectCreated < ::Types::BaseObject
        graphql_name 'PolicyProjectCreated'
        description 'Response of security policy creation.'

        field :project, Types::ProjectType,
          null: true,
          description: 'Security Policy Project that was created.'

        field :status, Types::GitlabSubscriptions::Security::PolicyProjectCreatedStatusEnum,
          description: 'Status of the creation of the security policy project.'

        field :error_message, GraphQL::Types::String,
          null: true,
          description: 'Error message in case status is :error.'
      end
      # rubocop:enable Graphql/AuthorizeTypes
    end
  end
end
