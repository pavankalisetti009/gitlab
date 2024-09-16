# frozen_string_literal: true

module Vulnerabilities
  module Removal
    module Tasks
      class DeleteFindingPipelines < AbstractTaskScopedToFinding
        self.model = Vulnerabilities::FindingPipeline
      end
    end
  end
end
