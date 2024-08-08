# frozen_string_literal: true

module EE
  class MergeRequestAiEntity < ::API::Entities::MergeRequest
    expose :diff do |mr, options|
      ::Gitlab::Llm::Utils::MergeRequestTool.extract_diff(
        source_project: mr.source_project,
        source_branch: mr.source_branch,
        target_project: mr.target_project,
        target_branch: mr.target_branch,
        character_limit: options[:notes_limit] / 2
      )
    end

    expose :mr_comments do |_mr, options|
      options[:resource].notes_with_limit(notes_limit: options[:notes_limit] / 2)
    end
  end
end
