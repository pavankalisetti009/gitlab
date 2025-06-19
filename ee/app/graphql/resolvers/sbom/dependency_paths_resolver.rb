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
        sbom_occurrence = ::Sbom::Occurrence.find(occurrence_id)

        return unless sbom_occurrence

        ::Sbom::PathFinder.execute(sbom_occurrence)
      end

      private

      def resolve_gid(gid, gid_class)
        Types::GlobalIDType[gid_class].coerce_isolated_input(gid).model_id
      end
    end
  end
end
