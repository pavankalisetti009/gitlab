# frozen_string_literal: true

module Resolvers
  module Ai
    module Catalog
      class ItemResolver < BaseResolver
        description 'Find an AI Catalog item.'

        type ::Types::Ai::Catalog::ItemInterface, null: true

        argument :id,
          ::Types::GlobalIDType[::Ai::Catalog::Item],
          required: true,
          description: 'Global ID of the catalog item to find.'

        def resolve(id:)
          Gitlab::Graphql::Lazy.with_value(find_object(id: id)) do |item|
            next if item&.deleted?

            item
          end
        end

        private

        def find_object(id:)
          GitlabSchema.find_by_gid(id)
        end
      end
    end
  end
end
