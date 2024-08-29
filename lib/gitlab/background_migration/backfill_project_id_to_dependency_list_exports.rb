# frozen_string_literal: true

module Gitlab
  module BackgroundMigration
    class BackfillProjectIdToDependencyListExports < BatchedMigrationJob
      operation_name :backfill_project_id_to_dependency_list_exports
      scope_to ->(relation) { relation.where.not(pipeline_id: nil) }
      feature_category :dependency_management

      class DependencyListExport < ::ApplicationRecord
        self.table_name = 'dependency_list_exports'
      end

      class Pipeline < ::Ci::ApplicationRecord
        self.table_name = 'p_ci_pipelines'
      end

      def perform
        each_sub_batch do |exports|
          pipelines = Pipeline.id_in(exports.pluck(:pipeline_id))

          tuples_to_update = pipelines.map do |pipeline|
            [pipeline.id, pipeline.project_id]
          end

          bulk_update!(tuples_to_update)
        end
      end

      def bulk_update!(tuples)
        values_sql = Arel::Nodes::ValuesList.new(tuples).to_sql

        sql = <<~SQL
          UPDATE
            dependency_list_exports
          SET
            project_id = tuples.project_id
          FROM
            (#{values_sql}) AS tuples(pipeline_id, project_id)
          WHERE
            dependency_list_exports.pipeline_id = tuples.pipeline_id;
        SQL

        DependencyListExport.connection.execute(sql)
      end
    end
  end
end
