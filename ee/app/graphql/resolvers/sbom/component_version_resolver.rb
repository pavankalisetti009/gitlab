# frozen_string_literal: true

module Resolvers
  module Sbom
    class ComponentVersionResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type [::Types::Sbom::ComponentVersionType], null: true

      description 'Software dependency versions, filtered by component'

      argument :component_id, ::Types::GlobalIDType[::Sbom::Component],
        required: true,
        description: 'Global ID of the SBoM component.'

      def resolve(component_id: nil)
        ::Sbom::ComponentVersionsFinder.new(object, component_id.model_id).execute
      end
    end
  end
end
