# frozen_string_literal: true

module Types
  module Security
    class TrackedRefType < BaseObject
      graphql_name 'SecurityTrackedRef'
      description 'Represents a ref (branch or tag) tracked for security vulnerabilities'

      authorize :read_security_project_tracked_refs

      field :id, GraphQL::Types::ID, null: false,
        description: 'Global ID of the tracked ref.'

      field :name, GraphQL::Types::String, null: false,
        description: 'Name of the ref (branch or tag name).',
        method: :context_name

      field :ref_type, Types::Security::TrackedRefTypeEnum, null: false,
        description: 'Type of the ref being tracked.',
        method: :context_type

      field :is_default, GraphQL::Types::Boolean, null: false,
        description: 'Whether the ref is the default branch.'

      field :is_protected, GraphQL::Types::Boolean, null: false,
        description: 'Whether the ref is protected.'

      field :commit, Types::Repositories::CommitType, null: true,
        description: 'Latest commit on the ref.'

      field :vulnerabilities_count, GraphQL::Types::Int, null: false,
        description: 'Count of open vulnerabilities on the ref.'

      field :tracked_at, Types::TimeType, null: false,
        description: 'When tracking was enabled for the ref.',
        method: :created_at

      field :state, Types::Security::TrackedRefStateEnum, null: false,
        description: 'Current tracking state of the ref.'

      def state
        object.tracked? ? 'TRACKED' : 'UNTRACKED'
      end
    end
  end
end
