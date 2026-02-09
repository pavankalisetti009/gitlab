# frozen_string_literal: true

module Search
  module Elastic
    class WorkItemQueryBuilder < QueryBuilder
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize

      DOC_TYPE = 'work_item'
      # iid field can be added here as lenient option will pardon format errors, like integer out of range.
      FIELDS = %w[iid^50 title^2 description].freeze

      # rubocop:disable Metrics/AbcSize -- For now it seems that build steps are logically cohesive as a single unit
      def build
        options[:fields] = fields
        options[:related_ids] = related_ids
        options[:use_group_authorization] = use_group_authorization?
        options[:use_project_authorization] = use_project_authorization?
        options[:features] = 'issues' if use_project_authorization?

        query_hash = build_query_hash(query: query, options: options)

        query_hash = get_authorization_filter(query_hash: query_hash, options: options)
        query_hash = get_confidentiality_filter(query_hash: query_hash, options: options)

        query_hash = ::Search::Elastic::Filters.by_state(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_not_hidden(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_label_ids(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_archived(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_work_item_type_ids(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_author(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_assignees(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_milestone(query_hash: query_hash, options: options)

        query_hash = ::Search::Elastic::Filters.by_milestone_state(query_hash: query_hash, options: options)

        query_hash = ::Search::Elastic::Filters.by_label_names(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_weight(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_health_status(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_closed_at(query_hash: query_hash, options: options)

        query_hash = ::Search::Elastic::Filters.by_created_at(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_updated_at(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_due_date(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_iids(query_hash: query_hash, options: options)

        return ::Search::Elastic::Aggregations.by_label_ids(query_hash: query_hash) if options[:aggregation]

        query_hash = ::Search::Elastic::Formats.source_fields(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.page(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.size(query_hash: query_hash, options: options)

        ::Search::Elastic::Sorts.sort_by(query_hash: query_hash, options: options)
      end
      # rubocop:enable Metrics/AbcSize

      private

      def fields
        return options[:fields] if options[:fields].presence

        FIELDS
      end

      def related_ids
        return [] unless options[:related_ids].present?

        # related_ids are used to search for related notes on noteable records
        # this is not enabled on GitLab.com for global searches
        return [] if options[:search_level].to_sym == :global && ::Gitlab::Saas.feature_available?(:advanced_search)

        options[:related_ids]
      end

      def get_authorization_filter(query_hash:, options:)
        ::Search::Elastic::Filters.by_combined_search_level_and_membership(query_hash:, options:)
      end

      def get_confidentiality_filter(query_hash:, options:)
        ::Search::Elastic::Filters.by_combined_confidentiality(query_hash:, options:)
      end

      override :extra_options
      def extra_options
        {
          authorization_use_traversal_ids: true,
          doc_type: DOC_TYPE,
          project_visibility_level_field: :project_visibility_level,
          min_access_level_confidential_public_internal: ::Gitlab::Access::GUEST,
          min_access_level_confidential: ::Gitlab::Access::PLANNER
        }
      end

      def iid_query?
        query =~ /#(\d+)\z/
      end

      def build_query_hash(query:, options:)
        if iid_query?
          query =~ /#(\d+)\z/ # To get the match correctly
          ::Search::Elastic::Queries.by_iid(iid: Regexp.last_match(1), doc_type: DOC_TYPE)
        else
          ::Search::Elastic::Queries.by_full_text(query: query, options: options)
        end
      end

      def use_project_authorization?
        return true unless options[:work_item_type_ids].present?

        project_work_item_type_ids = options[:work_item_type_ids] - group_work_item_type_ids
        project_work_item_type_ids.present?
      end

      def use_group_authorization?
        # If explicit type inclusion filter is present
        if options[:work_item_type_ids].present?
          return options[:work_item_type_ids].any? { |id| group_work_item_type_ids.include?(id) }
        end

        # If explicit type exclusion filter is present
        if options[:not_work_item_type_ids].present?
          # Use group auth only if epic is NOT excluded
          return !options[:not_work_item_type_ids].any? { |id| group_work_item_type_ids.include?(id) }
        end

        # No filter specified - include all types (including group-level)
        true
      end

      def group_work_item_type_ids
        [::WorkItems::TypesFramework::Provider.new.find_by_base_type(:epic).id].freeze
      end
      strong_memoize_attr :group_work_item_type_ids
    end
  end
end
