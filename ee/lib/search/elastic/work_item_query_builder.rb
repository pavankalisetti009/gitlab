# frozen_string_literal: true

module Search
  module Elastic
    class WorkItemQueryBuilder < QueryBuilder
      extend ::Gitlab::Utils::Override

      DOC_TYPE = 'work_item'

      def build
        query_hash =
          if query =~ /#(\d+)\z/
            ::Search::Elastic::Queries.by_iid(iid: Regexp.last_match(1), doc_type: DOC_TYPE)
          else
            # iid field can be added here as lenient option will
            # pardon format errors, like integer out of range.
            fields = %w[iid^3 title^2 description]

            if !::Search::Elastic::Queries::ADVANCED_QUERY_SYNTAX_REGEX.match?(query) &&
                Feature.enabled?(:search_uses_match_queries, options[:current_user])
              ::Search::Elastic::Queries.by_multi_match_query(fields: fields, query: query, options: options)
            else
              ::Search::Elastic::Queries.by_simple_query_string(fields: fields, query: query, options: options)
            end
          end

        query_hash = if options[:group_level_authorization]
                       ::Search::Elastic::Filters.by_group_level_authorization(query_hash: query_hash, options: options)
                     else
                       ::Search::Elastic::Filters.by_authorization(query_hash: query_hash, options: options)
                     end

        query_hash = if options[:group_level_confidentiality]
                       ::Search::Elastic::Filters.by_group_level_confidentiality(query_hash: query_hash,
                         options: options)
                     else
                       ::Search::Elastic::Filters.by_confidentiality(query_hash: query_hash, options: options)
                     end

        query_hash = ::Search::Elastic::Filters.by_state(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_not_hidden(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_label_ids(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_archived(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_work_item_type_ids(query_hash: query_hash, options: options)

        return ::Search::Elastic::Aggregations.by_label_ids(query_hash: query_hash) if options[:aggregation]

        query_hash = ::Search::Elastic::Formats.source_fields(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.page(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.size(query_hash: query_hash, options: options)

        ::Search::Elastic::Sorts.sort_by(query_hash: query_hash, options: options)
      end

      private

      override :extra_options
      def extra_options
        {
          doc_type: DOC_TYPE,
          features: 'issues',
          authorization_use_traversal_ids: true,
          project_visibility_level_field: :project_visibility_level
        }
      end
    end
  end
end
