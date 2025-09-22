# frozen_string_literal: true

module API
  module Entities
    module Ai
      module DuoWorkflows
        class Checkpoint < BasicCheckpoint
          expose :checkpoint
          expose :checkpoint_writes, using: 'API::Entities::Ai::DuoWorkflows::CheckpointWrite'
          expose :metadata
        end
      end
    end
  end
end
