# frozen_string_literal: true

module Search
  module Elastic
    class MergeRequestQueryBuilder < QueryBuilder
      extend ::Gitlab::Utils::Override

      DOC_TYPE = 'merge_request'
      # iid field can be added here as lenient option will pardon format errors, like integer out of range.
      FIELDS = %w[iid^3 title^2 description].freeze

      def build
        options[:fields] = options[:fields].presence || FIELDS
        options[:related_ids] = related_ids

        query_hash = build_query_hash(query: query, options: options)
        query_hash = ::Search::Elastic::Filters.by_project_authorization(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_state(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_archived(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_author(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_label_ids(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_source_branch(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_target_branch(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_not_hidden(query_hash: query_hash, options: options)

        return ::Search::Elastic::Aggregations.by_label_ids(query_hash: query_hash) if options[:aggregation]

        query_hash = ::Search::Elastic::Formats.source_fields(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.size(query_hash: query_hash, options: options)

        ::Search::Elastic::Sorts.sort_by(query_hash: query_hash, options: options)
      end

      private

      def related_ids
        return [] unless options[:related_ids].present?
        return [] unless Feature.enabled?(:search_merge_request_queries_notes, options[:current_user])

        # related_ids are used to search for related notes on noteable records
        # this is not enabled on GitLab.com for global searches
        return [] if options[:search_level].to_sym == :global && ::Gitlab::Saas.feature_available?(:advanced_search)

        options[:related_ids]
      end

      override :extra_options
      def extra_options
        {
          doc_type: DOC_TYPE,
          features: 'merge_requests',
          project_id_field: :target_project_id,
          authorization_use_traversal_ids: false # https://gitlab.com/gitlab-org/gitlab/-/issues/491211
        }
      end

      def build_query_hash(query:, options:)
        if query =~ /!(\d+)\z/
          ::Search::Elastic::Queries.by_iid(iid: Regexp.last_match(1), doc_type: DOC_TYPE)
        else
          ::Search::Elastic::Queries.by_full_text(query: query, options: options)
        end
      end
    end
  end
end
