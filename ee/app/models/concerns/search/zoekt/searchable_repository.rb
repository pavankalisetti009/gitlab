# frozen_string_literal: true

module Search
  module Zoekt
    module SearchableRepository
      extend ActiveSupport::Concern

      included do
        def use_zoekt?
          project&.use_zoekt?
        end

        def update_zoekt_index!(force: false)
          Router.fetch_nodes_for_indexing(project.id, root_namespace_id: project.root_ancestor.id).map do |node|
            ::Gitlab::Search::Zoekt::Client.index(project, node.id, force: force)
          end
        end

        def async_update_zoekt_index
          ::Search::Zoekt.index_async(project.id)
        end
      end
    end
  end
end
