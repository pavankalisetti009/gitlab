# frozen_string_literal: true

module Search
  module Elastic
    class MergeRequestQueryBuilder < QueryBuilder
      extend ::Gitlab::Utils::Override

      DOC_TYPE = 'merge_request'

      def build
        query_hash = build_query_hash(query: query, options: options)
        query_hash = ::Search::Elastic::Filters.by_project_authorization(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_state(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_archived(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_author(query_hash: query_hash, options: options)

        if Feature.enabled?(:search_mr_filter_source_branch, options[:current_user])
          query_hash = ::Search::Elastic::Filters.by_source_branch(query_hash: query_hash, options: options)
        end

        if Feature.enabled?(:search_mr_filter_target_branch, options[:current_user])
          query_hash = ::Search::Elastic::Filters.by_target_branch(query_hash: query_hash, options: options)
        end

        if Feature.enabled?(:hide_merge_requests_from_banned_users) # rubocop: disable Gitlab/FeatureFlagWithoutActor -- existing flag
          query_hash = ::Search::Elastic::Filters.by_not_hidden(query_hash: query_hash, options: options)
        end

        if ::Elastic::DataMigrationService.migration_has_finished?(:reindex_merge_requests_to_backfill_label_ids)
          query_hash = ::Search::Elastic::Filters.by_label_ids(query_hash: query_hash, options: options)

          return ::Search::Elastic::Aggregations.by_label_ids(query_hash: query_hash) if options[:aggregation]
        end

        query_hash = ::Search::Elastic::Formats.source_fields(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.size(query_hash: query_hash, options: options)

        ::Search::Elastic::Sorts.sort_by(query_hash: query_hash, options: options)
      end

      private

      override :extra_options
      def extra_options
        {
          doc_type: DOC_TYPE,
          features: 'merge_requests',
          project_id_field: :target_project_id,
          authorization_use_traversal_ids: false # https://gitlab.com/gitlab-org/gitlab/-/issues/351279
        }
      end

      def build_query_hash(query:, options:)
        if query =~ /!(\d+)\z/
          ::Search::Elastic::Queries.by_iid(iid: Regexp.last_match(1), doc_type: DOC_TYPE)
        else
          # iid field can be added here as lenient option will pardon format errors, like integer out of range.
          fields = options[:fields].presence || %w[iid^3 title^2 description]

          if !::Search::Elastic::Queries::ADVANCED_QUERY_SYNTAX_REGEX.match?(query) &&
              Feature.enabled?(:search_uses_match_queries, options[:current_user])
            ::Search::Elastic::Queries.by_multi_match_query(fields: fields, query: query, options: options)
          else
            ::Search::Elastic::Queries.by_simple_query_string(fields: fields, query: query, options: options)
          end
        end
      end
    end
  end
end
