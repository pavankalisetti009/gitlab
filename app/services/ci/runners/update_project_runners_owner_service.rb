# frozen_string_literal: true

module Ci
  module Runners
    # Service used to recompute runner owners after a project is deleted.
    class UpdateProjectRunnersOwnerService
      BATCH_SIZE = 1000

      # @param [Int] project_id: the ID of the deleted project
      def initialize(project_id)
        @project_id = project_id
      end

      def execute
        # Since the project was deleted in the 'main' database, let's ensure that the respective
        # ci_runner_projects join records are also gone (would be handled by LFK otherwise,
        # but it is a helpful precondition for the service's logic)
        Ci::RunnerProject.belonging_to_project(project_id).delete_all

        lateral_query_arel = lateral_subquery.arel.as('owner_runner_project')

        # rubocop: disable CodeReuse/ActiveRecord -- this query is too specific to generalize on the models
        query = Ci::Runner.project_type.with_sharding_key(project_id)
          .joins("CROSS JOIN LATERAL (#{lateral_subquery.to_sql}) #{lateral_query_arel.name}")
          .where(lateral_query_arel[:project_id].not_eq(project_id))
          .select(Ci::Runner.arel_table[:id], lateral_query_arel[:project_id])

        query.each_batch(of: BATCH_SIZE) do |batch|
          runner_id_to_project_id = batch.limit(BATCH_SIZE).pluck(:id, :project_id)
          runner_id_to_project_id_as_json = runner_id_to_project_id.to_h.transform_keys(&:to_s).to_json
          id_update_query = runner_id_update_query(runner_id_to_project_id_as_json, 'id')
          runner_id_update_query = runner_id_update_query(runner_id_to_project_id_as_json, 'runner_id')
          runner_ids = runner_id_to_project_id.map(&:first)

          Ci::Runner.transaction do
            Ci::Runner.project_type.id_in(runner_ids).update_all id_update_query
            Ci::RunnerManager.project_type.for_runner(runner_ids).update_all runner_id_update_query
          end
        end
        # rubocop: enable CodeReuse/ActiveRecord

        # Delete any orphaned runners that are still pointing to the project
        #   (they are the ones which no longer have any matching ci_runner_projects records)
        # We can afford to sidestep Ci::Runner hooks since we know by definition that
        # there are no Ci::RunnerProject models pointing to these runners (it's the reason they are being deleted)
        Ci::Runner.project_type.with_sharding_key(project_id).delete_all

        ServiceResponse.success
      end

      private

      attr_reader :project_id

      def lateral_subquery
        # rubocop: disable CodeReuse/ActiveRecord -- this query is too specific to generalize on the models
        Ci::RunnerProject
          .where(Ci::RunnerProject.arel_table[:runner_id].eq(Ci::Runner.arel_table[:id]))
          .select(:project_id)
          .order(id: :asc)
          .limit(1)
        # rubocop: enable CodeReuse/ActiveRecord
      end

      def runner_id_update_query(runner_id_to_project_id_as_json, runner_id_column)
        <<~SQL
          sharding_key_id = (
            SELECT value::integer
            FROM jsonb_each_text('#{runner_id_to_project_id_as_json}'::jsonb)
            WHERE key::integer = #{runner_id_column}
          )
        SQL
      end
    end
  end
end
