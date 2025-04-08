# frozen_string_literal: true

# Used to filter Work Items collections by set of params in Elasticsearch
#
# Arguments:
#   current_user    - ActiveRecord instance representing the currently logged-in user
#   resource_parent - ActiveRecord instance representing the parent of the work items (either a Project or a Group)
#   context         - GraphQL context object (an instance of GraphQL::Query::Context) that holds per-request metadata,
#                     such as the HTTP request, current user, etc.
#   params:
#     state        - String with possible values of 'opened', 'closed', or 'all'
#     group_id     - ActiveRecord Group instance
#     project_id   - ActiveRecord Project instance
#     label_name   - Array of strings
#     sort         - Symbol with possible values of :created_desc or :created_asc
#     confidential - Boolean

module EE
  module WorkItems
    module Glql
      module WorkItemsFinder
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        CONTROL_KEYS = [:sort, :include_ancestors, :include_descendants, :exclude_projects].freeze
        ALLOWED_ES_FILTERS = [:label_name, :group_id, :project_id, :state, :confidential].freeze

        attr_reader :current_user, :context, :params
        attr_accessor :resource_parent

        def execute
          result = search_service.search_results.objects('issues')

          ::WorkItem.glql_from_es_results(result)
        end

        override :use_elasticsearch_finder?
        def use_elasticsearch_finder?
          glql_request? &&
            url_param_enabled? &&
            use_elasticsearch? &&
            elasticsearch_enabled_for_namespace? &&
            elasticsearch_fields_supported?
        end

        # The logic for parent_param is copied from app/finders/issuable_finder.rb
        # Otherwise `find_all` fails in lib/gitlab/graphql/loaders/issuable_loader.rb
        def parent_param=(obj)
          self.resource_parent = obj
          params[parent_param] = resource_parent if resource_parent
        end

        def parent_param
          case resource_parent
          when Project
            :project_id
          when Group
            :group_id
          else
            raise "Unexpected parent: #{resource_parent.class}"
          end
        end

        private

        def search_service
          ::SearchService.new(current_user, search_params)
        end

        def search_params
          base_params.merge(scope_param)
        end

        def base_params
          {
            search: '*',
            per_page: 100,
            label_name: params[:label_name],
            sort: 'created_desc',
            state: params[:state],
            confidential: params[:confidential]
          }
        end

        def scope_param
          if params[:project_id].present?
            { project_id: params[:project_id]&.id }
          else
            { group_id: params[:group_id]&.id }
          end
        end

        def use_elasticsearch?
          ::Gitlab::CurrentSettings.elasticsearch_search?
        end

        def elasticsearch_enabled_for_namespace?
          resource_parent.use_elasticsearch?
        end

        def glql_request?
          return unless request_params.present?

          request_params.fetch('operationName', nil) == 'GLQL'
        end

        def url_param_enabled?
          # Expected params are `useES=true` or `useES=false`
          # Defaults to `true` if no param is given
          # Otherwise fetches the value from the param when provided
          default = true
          use_es_value = request_referer_params.fetch('useES', [default]).first
          value = use_es_value.to_s.strip.downcase

          { 'true' => true, 'false' => false }.fetch(value, default)
        end

        def request_from_context
          context[:request]
        end

        def request_params
          request_from_context&.params
        end

        def request_referer
          request_from_context&.referer
        end

        def request_referer_params
          return {} unless request_referer.present?

          uri = URI.parse(request_referer)

          CGI.parse(uri.query.to_s)
        end

        def elasticsearch_fields_supported?
          filter_keys = params.keys - CONTROL_KEYS

          (filter_keys - ALLOWED_ES_FILTERS).empty?
        end
      end
    end
  end
end
