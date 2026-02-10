# frozen_string_literal: true

module EE
  module API
    module Search
      ADVANCED_SEARCH_SCOPES = %w[blobs commits notes wiki_blobs].freeze
      BLOB_SEARCH_TYPES = %w[advanced zoekt].freeze
      ADVANCED_SEARCH_SEARCH_TYPE = 'advanced'
      FIELDS_SUPPORTED_SCOPES = %w[issues merge_requests].freeze

      extend ActiveSupport::Concern

      prepended do
        helpers do
          include ::API::Helpers::SearchHelpers
          extend ::Gitlab::Utils::Override

          params :ee_param_fields do
            optional :fields, type: Array[String], coerce_with: ::API::Validations::Types::CommaSeparatedToArray.coerce,
              values: %w[title], desc: 'Array of fields you wish to search. Available with advanced search.'
          end

          params :ee_param_exclude_forks do
            optional :exclude_forks, type: Grape::API::Boolean,
              desc: 'Excludes forked projects in the search. Available with exact code search. Introduced in GitLab 18.9.' # rubocop:disable Layout/LineLength,Lint/RedundantCopDisableDirective -- keep readability
          end

          params :ee_param_regex do
            optional :regex, type: Grape::API::Boolean,
              desc: 'Performs a regex code search. Available with exact code search. Introduced in GitLab 18.9'
          end

          override :scope_preload_method
          def scope_preload_method
            super.merge(blobs: :with_api_blob_entity_associations).freeze
          end

          # do not use this method for project search API
          # all search scopes allowed for project level search
          override :verify_search_scope_for_ee!
          def verify_search_scope_for_ee!(search_type)
            scope = user_requested_search_scope
            return if scope == 'blobs' && BLOB_SEARCH_TYPES.include?(search_type)
            return if ADVANCED_SEARCH_SCOPES.exclude?(scope) || search_type == ADVANCED_SEARCH_SEARCH_TYPE

            render_api_error!({ error: scope_error_message(scope) }, 400)
          end

          def scope_error_message(scope)
            return 'Scope supported only with advanced search or exact code search' if scope == 'blobs'

            'Scope supported only with advanced search'
          end

          override :verify_ee_param_regex!
          def verify_ee_param_regex!(search_type)
            return unless params.key?(:regex)
            return if search_type == 'zoekt'

            render_api_error!({ error: 'regex supported only with exact code search' }, 400)
          end

          override :verify_ee_param_exclude_forks!
          def verify_ee_param_exclude_forks!(search_type)
            return unless params.key?(:exclude_forks)
            return if search_type == 'zoekt'

            render_api_error!({ error: 'exclude_forks supported only with exact code search' }, 400)
          end

          override :verify_ee_param_fields!
          def verify_ee_param_fields!(search_type)
            return unless params.key?(:fields)

            if FIELDS_SUPPORTED_SCOPES.exclude?(user_requested_search_scope)
              render_api_error!({ error: "fields is supported only for #{FIELDS_SUPPORTED_SCOPES.join(', ')}" }, 400)
            end

            return if search_type == ADVANCED_SEARCH_SEARCH_TYPE

            render_api_error!({ error: "fields is supported only for #{ADVANCED_SEARCH_SEARCH_TYPE} search" }, 400)
          end
        end
      end
    end
  end
end
