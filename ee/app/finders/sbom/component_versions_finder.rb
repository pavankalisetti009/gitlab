# frozen_string_literal: true

module Sbom
  class ComponentVersionsFinder
    def initialize(object, component_id)
      @object = object
      @component_id = component_id
    end

    def execute
      if object.is_a?(Project) && Feature.enabled?(:version_filtering_on_project_level_dependency_list, object)
        Sbom::ComponentVersion.by_project_and_component(object.id, component_id)
      else
        Sbom::ComponentVersion.none
      end
    end

    private

    attr_reader :object, :component_id
  end
end
