# frozen_string_literal: true

module Gitlab
  module CodeOwners
    module OwnerValidation
      class QualifiedGroupsFilter
        include ::Gitlab::Utils::StrongMemoize

        def initialize(project, groups:, group_names:)
          @project = project
          @input_groups = groups
          @input_group_names = group_names
        end

        def error_message
          :unqualified_group
        end

        def output_groups
          group_traversal_ids = project.group.traversal_ids
          group_and_ancestors = input_groups.select { |group| group.id.in?(group_traversal_ids) }
          eligible_invited_groups = project.invited_groups.with_developer_access.by_id(input_groups)
          group_and_ancestors + eligible_invited_groups
        end
        strong_memoize_attr :output_groups

        def valid_group_names
          output_groups.map(&:full_path)
        end
        strong_memoize_attr :valid_group_names

        def invalid_group_names
          input_group_names - valid_group_names
        end
        strong_memoize_attr :invalid_group_names

        private

        attr_reader :project, :input_groups, :input_group_names
      end
    end
  end
end
