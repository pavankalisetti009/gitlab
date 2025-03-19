# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module Completions
        class SummarizeNewMergeRequest < Base
          extend ::Gitlab::Utils::Override
          include Gitlab::Utils::StrongMemoize

          CHARACTER_LIMIT = 2000

          override :inputs
          def inputs
            { extracted_diff: extracted_diff }
          end

          private

          def extracted_diff
            Gitlab::Llm::Utils::MergeRequestTool.extract_diff(
              source_project: source_project,
              source_branch: options[:source_branch],
              target_project: resource,
              target_branch: options[:target_branch],
              character_limit: CHARACTER_LIMIT
            )
          end
          strong_memoize_attr :extracted_diff

          override :valid?
          def valid?
            super && extracted_diff.present?
          end

          override :prompt_version
          def prompt_version
            '2.0.2-dev' if Feature.enabled?(:summarize_merge_request_claude_3_7_sonnet, user)
          end

          def source_project
            return resource unless options[:source_project_id]

            source_project = Project.find_by_id(options[:source_project_id])

            return source_project if source_project.present? && user.can?(:create_merge_request_from, source_project)

            resource
          end
        end
      end
    end
  end
end
