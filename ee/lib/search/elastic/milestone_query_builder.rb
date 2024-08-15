# frozen_string_literal: true

module Search
  module Elastic
    class MilestoneQueryBuilder < QueryBuilder
      extend ::Gitlab::Utils::Override

      DOC_TYPE = 'milestone'

      def build
        fields = %w[title^2 description]
        query_hash = if !::Search::Elastic::Queries::ADVANCED_QUERY_SYNTAX_REGEX.match?(query) &&
            Feature.enabled?(:search_uses_match_queries, options[:current_user])
                       ::Search::Elastic::Queries.by_multi_match_query(fields: fields, query: query, options: options)
                     else
                       ::Search::Elastic::Queries.by_simple_query_string(fields: fields, query: query, options: options)
                     end

        query_hash = ::Search::Elastic::Filters.by_type(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_authorization(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_archived(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.source_fields(query_hash: query_hash, options: options)
        ::Search::Elastic::Formats.size(query_hash: query_hash, options: options)
      end

      private

      override :extra_options
      def extra_options
        {
          doc_type: DOC_TYPE,
          features: [:issues, :merge_requests],
          authorization_use_traversal_ids: false
        }
      end
    end
  end
end
