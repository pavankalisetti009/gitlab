# frozen_string_literal: true

module Sbom
  class DependencyPathEntity < Grape::Entity
    expose :path
    expose :is_cyclic
    expose :max_depth_reached
  end
end
