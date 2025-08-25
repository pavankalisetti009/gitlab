# frozen_string_literal: true

module Search
  module Elastic
    module Sorts
      SORT_MAPPINGS = {
        created_at_asc: { created_at: { order: 'asc' } },
        created_at_desc: { created_at: { order: 'desc' } },
        updated_at_asc: { updated_at: { order: 'asc' } },
        updated_at_desc: { updated_at: { order: 'desc' } },
        popularity_asc: { upvotes: { order: 'asc' } },
        popularity_desc: { upvotes: { order: 'desc' } },
        milestone_due_asc: { milestone_due_date: { order: 'asc' } },
        milestone_due_desc: { milestone_due_date: { order: 'desc' } },
        weight_asc: { weight: { order: 'asc' } },
        weight_desc: { weight: { order: 'desc' } },
        health_status_asc: { health_status: { order: 'asc' } },
        health_status_desc: { health_status: { order: 'desc' } },
        closed_at_asc: { closed_at: { order: 'asc' } },
        closed_at_desc: { closed_at: { order: 'desc' } },
        due_date_asc: { due_date: { order: 'asc' } },
        due_date_desc: { due_date: { order: 'desc' } }
      }.freeze

      class << self
        def sort_by(query_hash:, options:)
          sort_hash = build_sort(options[:doc_type], options[:order_by], options[:sort])
          query_hash.merge(sort: sort_hash)
        end

        private

        def build_sort(doc_type, order_by, sort)
          # Due to different uses of sort param we prefer order_by when present
          sort_and_direction = ::Gitlab::Search::SortOptions.sort_and_direction(order_by, sort)
          if ::Gitlab::Search::SortOptions::DOC_TYPE_ONLY_SORT[sort_and_direction] &&
              ::Gitlab::Search::SortOptions::DOC_TYPE_ONLY_SORT[sort_and_direction].exclude?(doc_type)
            sort_and_direction = nil
          end

          SORT_MAPPINGS.fetch(sort_and_direction, {})
        end
      end
    end
  end
end
