# frozen_string_literal: true

module Resolvers
  module Ai
    module Catalog
      class ItemsResolver < BaseResolver
        include LooksAhead

        description 'AI Catalog items.'

        type ::Types::Ai::Catalog::ItemInterface.connection_type, null: false

        def resolve_with_lookahead
          return ::Ai::Catalog::Item.none unless ::Feature.enabled?(:global_ai_catalog, current_user)

          apply_lookahead(::Ai::Catalog::Item.not_deleted)
        end

        def preloads
          {
            versions: :versions,
            # TODO: Optimize loading of latest version https://gitlab.com/gitlab-org/gitlab/-/issues/554673
            latest_version: :latest_version
          }
        end
      end
    end
  end
end
