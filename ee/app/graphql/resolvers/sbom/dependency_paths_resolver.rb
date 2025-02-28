# frozen_string_literal: true

module Resolvers
  module Sbom
    class DependencyPathsResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type [Types::Sbom::DependencyPathType], null: true

      authorize :read_dependency
      authorizes_object!

      argument :component, Types::GlobalIDType[::Sbom::Component],
        required: true,
        description: 'Dependency path for component.'

      alias_method :project, :object

      def resolve(component:)
        return if Feature.disabled?(:dependency_graph_graphql, project)

        component_id = resolve_gid(component, ::Sbom::Component)
        result = Gitlab::Metrics.measure(:dependency_path_cte) do
          ::Sbom::DependencyPath.find(id: component_id, project_id: project.id)
        end
        record_metrics(result)
        result
      end

      private

      def resolve_gid(gid, gid_class)
        Types::GlobalIDType[gid_class].coerce_isolated_input(gid).model_id
      end

      def record_metrics(result)
        counter = Gitlab::Metrics.counter(
          :dependency_path_cte_paths_found,
          'Count of Dependency Paths found using the recursive CTE'
        )

        counter.increment(
          { cyclic: false, max_depth_reached: false },
          result.count { |r| !r.is_cyclic && !r.max_depth_reached }
        )
        counter.increment(
          { cyclic: false, max_depth_reached: true },
          result.count { |r| !r.is_cyclic && r.max_depth_reached }
        )
        counter.increment(
          { cyclic: true, max_depth_reached: false },
          result.count { |r| r.is_cyclic && !r.max_depth_reached }
        )
        counter.increment(
          { cyclic: true, max_depth_reached: true },
          result.count { |r| r.is_cyclic && r.max_depth_reached }
        )
      end
    end
  end
end
