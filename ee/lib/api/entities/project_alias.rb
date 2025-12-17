# frozen_string_literal: true

module API
  module Entities
    class ProjectAlias < Grape::Entity
      expose :id, documentation: { type: 'Integer', example: 1 }
      expose :project_id, documentation: { type: 'Integer', example: 1 }
      expose :name, documentation: { type: 'String', example: 'gitlab' }
    end
  end
end
