# frozen_string_literal: true

module Types
  module Security
    class TrackedRefType < BaseObject
      graphql_name 'SecurityTrackedRef'
      description 'Represents a ref (branch or tag) tracked for security vulnerabilities'

      connection_type_class Types::CountableConnectionType

      authorize :read_security_project_tracked_ref

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
        description: 'Whether the ref is protected.',
        calls_gitaly: true,
        resolver_method: :protected?

      field :commit, Types::Repositories::CommitType, null: true,
        description: 'Latest commit on the ref.',
        calls_gitaly: true

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

      def protected?
        return false unless ref_exists_in_repository?

        case object.context_type
        when 'branch'
          project.protected_branches.matching(object.context_name).any?
        when 'tag'
          project.protected_tags.matching(object.context_name).any?
        else
          false
        end
      end

      def commit
        return unless ref_exists_in_repository?

        qualified_ref = case object.context_type
                        when 'branch' then "#{Gitlab::Git::BRANCH_REF_PREFIX}#{object.context_name}"
                        when 'tag' then "#{Gitlab::Git::TAG_REF_PREFIX}#{object.context_name}"
                        end

        project.repository.commit(qualified_ref)
      rescue Gitlab::Git::Repository::NoRepository, Rugged::ReferenceError => e
        Gitlab::ErrorTracking.track_exception(e, project_id: project.id, ref_name: object.context_name)
        nil
      end

      def vulnerabilities_count
        object.vulnerability_reads.by_projects(object.project_id).count
      rescue StandardError => e
        Gitlab::ErrorTracking.track_exception(e, tracked_context_id: object.id)
        0
      end

      private

      def project
        @project ||= object.project
      end

      def ref_exists_in_repository?
        return false unless project.repository_exists?

        case object.context_type
        when 'branch'
          project.repository.branch_exists?(object.context_name)
        when 'tag'
          project.repository.tag_exists?(object.context_name)
        else
          false
        end
      end
    end
  end
end
