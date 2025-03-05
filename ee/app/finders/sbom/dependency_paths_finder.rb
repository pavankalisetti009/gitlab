# frozen_string_literal: true

module Sbom
  class DependencyPathsFinder
    def initialize(project, params: {})
      @project = project
      @params = params
    end

    def execute
      Sbom::DependencyPath.find(occurrence_id: params[:occurrence_id], project_id: project.id)
    end

    private

    attr_reader :project, :params
  end
end
