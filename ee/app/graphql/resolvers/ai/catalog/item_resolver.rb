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
          loads: ::Types::Ai::Catalog::ItemInterface,
          as: :item,
          description: 'Global ID of the catalog item to find.'

        def resolve(item:)
          # TODO We can remove this line when organization checks apply to all policy checks
          # as the type authorization will take care of this.
          # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/196700
          return unless item.organization == current_organization

          item
        end
      end
    end
  end
end
