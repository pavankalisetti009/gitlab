# frozen_string_literal: true

module Sbom
  class DependencyLocationEntity < Grape::Entity
    include RequestAwareEntity

    class LocationEntity < Grape::Entity
      expose :blob_path, :path, :top_level
      expose :dependency_paths, using: Sbom::DependencyPathEntity
    end

    class ProjectEntity < Grape::Entity
      expose :name
    end

    expose :location, using: LocationEntity
    expose :project, using: ProjectEntity
  end
end
