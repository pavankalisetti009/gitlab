# frozen_string_literal: true

module EE
  module API
    module Entities
      class MergeRequestDependency < Grape::Entity
        expose :id, documentation: { type: 'integer', example: 123 }
        expose :blocking_merge_request, using: ::API::Entities::MergeRequestBasic
        expose :blocked_merge_request, using: ::API::Entities::MergeRequestBasic
        expose :project_id, documentation: { type: 'integer', example: 312 }
      end
    end
  end
end
