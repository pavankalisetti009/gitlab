# frozen_string_literal: true

module API
  module Entities
    module Ai
      module DuoWorkflows
        class Workflow < Grape::Entity
          expose :id

          expose :pipeline do |_, opts|
            opts[:pipeline_id]
          end
        end
      end
    end
  end
end
