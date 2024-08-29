# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillProjectIdToDependencyListExports, feature_category: :dependency_management do
  let(:dependency_list_exports) { table(:dependency_list_exports) }
  let(:pipelines) { partitioned_table(:p_ci_pipelines, database: :ci) }
  let(:projects) { table(:projects) }
  let(:namespaces) { table(:namespaces) }

  let!(:pipeline) { create_ci_pipeline('pipeline-1') }

  let(:args) do
    min, max = dependency_list_exports.pick('MIN(pipeline_id)', 'MAX(pipeline_id)')

    {
      start_id: min,
      end_id: max,
      batch_table: 'dependency_list_exports',
      batch_column: 'pipeline_id',
      sub_batch_size: 1,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  subject(:perform_migration) { described_class.new(**args).perform }

  context 'when export is missing project_id' do
    let!(:export) { dependency_list_exports.create!(pipeline_id: pipeline.id) }
    let!(:other_pipeline) { create_ci_pipeline('pipeline-2') }
    let!(:other_export) { dependency_list_exports.create!(pipeline_id: other_pipeline.id) }

    it 'sets the project_id to build.project_id' do
      expect { perform_migration }.to change { export.reload.project_id }.from(nil).to(pipeline.project_id)
        .and change { other_export.reload.project_id }.from(nil).to(other_pipeline.project_id)
    end
  end

  def create_ci_pipeline(name)
    namespace = namespaces.create!(name: "group-#{name}", path: "group-#{name}")
    project_namespace = namespaces.create!(name: "project-#{name}", path: "project-#{name}")
    project = projects.create!(
      namespace_id: namespace.id,
      project_namespace_id: project_namespace.id,
      name: "project-#{name}",
      path: "project-#{name}"
    )
    pipelines.create!(project_id: project.id, partition_id: 100)
  end
end
