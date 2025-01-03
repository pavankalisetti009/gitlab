# frozen_string_literal: true

module Ci
  module Runners
    # Service used to recompute runner owners after a project is deleted.
    class UpdateProjectRunnersOwnerService
      # @param [Int] project_id: the ID of the deleted project
      def initialize(project_id)
        @project_id = project_id
      end

      def execute
        Ci::Runner.project_type.with_sharding_key(@project_id).find_each do |runner|
          # Recompute runner owner, deleting any runners that become orphaned
          next Ci::Runners::UnregisterRunnerService.new(runner, runner.token).execute if runner.owner.nil?

          runner.update_columns(sharding_key_id: runner.owner.id)
          runner.runner_managers.update_all(sharding_key_id: runner.owner.id)
        end

        ServiceResponse.success
      end
    end
  end
end
