# frozen_string_literal: true

module Resolvers
  module Sbom
    class DependencyPathsResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type [Types::Sbom::DependencyPathType], null: true

      authorize :read_dependency
      authorizes_object!

      argument :occurrence, Types::GlobalIDType[::Sbom::Occurrence],
        required: true,
        description: 'Dependency path for occurrence.'

      alias_method :project, :object

      def resolve(occurrence:)
        return if Feature.disabled?(:dependency_graph_graphql, project)

        occurrence_id = resolve_gid(occurrence, ::Sbom::Occurrence)
        result = Gitlab::Metrics.measure(:dependency_path_cte) do
          ::Sbom::DependencyPath.find(occurrence_id: occurrence_id, project_id: project.id)
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
