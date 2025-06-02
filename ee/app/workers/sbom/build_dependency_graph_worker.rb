# frozen_string_literal: true

module Sbom
  class BuildDependencyGraphWorker
    include ApplicationWorker

    idempotent!

    data_consistency :sticky
    worker_resource_boundary :cpu
    queue_namespace :sbom_graphs
    feature_category :dependency_management

    defer_on_database_health_signal :gitlab_sec, [:sbom_graph_paths], 1.minute

    def perform(project_id)
      project = Project.find_by_id(project_id)
      return unless project

      Sbom::BuildDependencyGraph.execute(project)
    end
  end
end
