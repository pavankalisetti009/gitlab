# frozen_string_literal: true

module API
  module Entities
    module Ai
      module KnowledgeGraph
        class EnabledNamespace < Grape::Entity
          expose :id, documentation: { type: 'Integer', example: 1234 }
          expose :root_namespace_id, documentation: { type: 'Integer', example: 5678 }
          expose :created_at, documentation: { type: 'DateTime', example: '2025-01-01T00:00:00Z' }
        end
      end
    end
  end
end
