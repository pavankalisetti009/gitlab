# frozen_string_literal: true

module EE
  module API
    module Search
      ELASTICSEARCH_SCOPES = %w[blobs commits notes wiki_blobs].freeze
      BLOB_SEARCH_TYPES = %w[advanced zoekt].freeze
      ELASTICSEARCH_SEARCH_TYPE = 'advanced'

      extend ActiveSupport::Concern

      prepended do
        helpers do
          include ::API::Helpers::SearchHelpers
          extend ::Gitlab::Utils::Override

          params :search_params_ee do
            optional :fields, type: Array[String], coerce_with: ::API::Validations::Types::CommaSeparatedToArray.coerce,
              values: %w[title], desc: 'Array of fields you wish to search'
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

              return render_api_error!({ error: 'Scope supported only with Elasticsearch or Zoekt' }, 400)
            end

            return if ELASTICSEARCH_SCOPES.exclude?(search_scope) || search_type == ELASTICSEARCH_SEARCH_TYPE

            render_api_error!({ error: 'Scope supported only with Elasticsearch' }, 400)
          end
        end
      end
    end
  end
end
