# frozen_string_literal: true

module EE
  module API
    module Search
      ADVANCED_SEARCH_SCOPES = %w[blobs commits notes wiki_blobs].freeze
      BLOB_SEARCH_TYPES = %w[advanced zoekt].freeze
      ADVANCED_SEARCH_SEARCH_TYPE = 'advanced'

      extend ActiveSupport::Concern

      prepended do
        helpers do
          include ::API::Helpers::SearchHelpers
          extend ::Gitlab::Utils::Override

          params :search_params_common_ee do
            optional :fields, type: Array[String], coerce_with: ::API::Validations::Types::CommaSeparatedToArray.coerce,
              values: %w[title], desc: 'Array of fields you wish to search. Available with advanced search.'
          end

          params :search_params_forks_filter_ee do
            optional :exclude_forks, type: Grape::API::Boolean, default: true,
              desc: 'Excludes forked projects in the search. Available with exact code search.'
          end

          override :scope_preload_method
          def scope_preload_method
            super.merge(blobs: :with_api_commit_entity_associations).freeze
          end

          override :verify_search_scope!
          def verify_search_scope!(additional_params = {})
            search_type = search_type(additional_params)
            if search_scope == 'blobs'
              return if BLOB_SEARCH_TYPES.include?(search_type)

              return render_api_error!({ error: 'Scope supported only with advanced search or exact code search' }, 400)
            end

            return if ADVANCED_SEARCH_SCOPES.exclude?(search_scope) || search_type == ADVANCED_SEARCH_SEARCH_TYPE

            render_api_error!({ error: 'Scope supported only with advanced search' }, 400)
          end
        end
      end
    end
  end
end
