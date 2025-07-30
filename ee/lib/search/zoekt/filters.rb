# frozen_string_literal: true

module Search
  module Zoekt
    module Filters
      class << self
        def by_substring(pattern:, case_sensitive: nil, file_name: nil, content: nil)
          filter = {
            pattern: pattern,
            case_sensitive: case_sensitive,
            file_name: file_name,
            content: content
          }.compact

          { substring: filter }
        end

        def by_repo_ids(ids)
          raise ArgumentError, "ids must be an Array, got #{ids.class}" unless ids.is_a?(Array)

          { repo_ids: ids.map(&:to_i) }
        end

        def by_project_ids(ids)
          raise ArgumentError, "ids must be an Array, got #{ids.class}" unless ids.is_a?(Array)
          raise ArgumentError, 'Project IDs cannot be empty' if ids.empty?

          return by_project_id(ids.first) if ids.size == 1

          or_filters(*ids.map { |id| by_project_id(id) })
        end

        def by_project_id(id)
          raise ArgumentError, 'Project ID cannot be nil' if id.nil?

          by_meta(key: 'project_id', value: "^#{id}$")
        end

        def by_regexp(regexp:, case_sensitive: nil, file_name: nil, content: nil)
          filter = {
            regexp: regexp,
            case_sensitive: case_sensitive,
            file_name: file_name,
            content: content
          }.compact

          { regexp: filter }
        end

        def and_filters(*filters)
          { and: { children: filters } }
        end

        def or_filters(*filters)
          { or: { children: filters } }
        end

        def not_filter(filter)
          { not: { child: filter } }
        end

        def by_symbol(expr)
          { symbol: { expr: expr } }
        end

        def by_meta(key:, value:)
          { meta: { key: key.to_s, value: value.to_s } }
        end

        def by_forked(value)
          by_meta(key: 'forked', value: value ? 't' : 'f')
        end

        def by_archived(value)
          by_meta(key: 'archived', value: value ? 't' : 'f')
        end

        def by_query_string(query)
          raise ArgumentError, 'Query string cannot be empty' if query.blank?

          { query_string: { query: query } }
        end

        def by_traversal_ids(traversal_ids)
          raise ArgumentError, 'Traversal IDs cannot be empty' if traversal_ids.blank?

          by_meta(key: 'traversal_ids', value: "^#{traversal_ids}")
        end
      end
    end
  end
end
