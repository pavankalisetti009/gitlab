# frozen_string_literal: true

module API
  module Entities
    class EpicIssue < ::API::Entities::Issue
      expose :epic_issue_id,
        documentation: {
          desc: 'ID of the epic-issue relation',
          type: 'Integer',
          example: 123
        }
      expose :relative_position,
        documentation: {
          desc: 'Relative position of the issue in the epic tree',
          type: 'Integer',
          example: 0
        }
    end
  end
end
