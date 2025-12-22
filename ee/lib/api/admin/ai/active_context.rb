# frozen_string_literal: true

module API
  module Admin
    module Ai
      class ActiveContext < ::API::Base
        feature_category :global_search
        urgency :low

        before do
          authenticated_as_admin!
        end

        helpers do
          def find_connection!(id = nil)
            connection = ::Ai::ActiveContext::Connection.find_connection(id)
            not_found!('Connection') unless connection
            connection
          end

          def find_collection!(connection, id)
            collection = find_collection(connection, id)
            not_found!('Collection') unless collection
            collection
          end

          def find_enabled_namespace!(connection, namespace)
            enabled_namespace =
              ::Ai::ActiveContext::Code::EnabledNamespace.find_enabled_namespace(connection, namespace)
            not_found!('Enabled Namespace') unless enabled_namespace
            enabled_namespace
          end

          private

          def find_collection(connection, id)
            return unless id

            if ::API::Helpers::INTEGER_ID_REGEX.match?(id.to_s)
              ::Ai::ActiveContext::Collection.find_by_id(connection, id)
            else
              ::Ai::ActiveContext::Collection.find_by_name(connection, id)
            end
          end
        end

        resources 'admin/active_context/connections' do
          desc 'Get all ActiveContext connections' do
            success ::API::Entities::Ai::ActiveContext::Connection
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' }
            ]
            tags %w[active_context]
          end
          get do
            present ::Ai::ActiveContext::Connection.all, with: ::API::Entities::Ai::ActiveContext::Connection
          end

          desc 'Activate an ActiveContext connection' do
            success ::API::Entities::Ai::ActiveContext::Connection
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' },
              { code: 404, message: '404 Not found' }
            ]
            tags %w[active_context]
          end
          params do
            requires :connection_id, type: Integer, desc: 'Connection ID'
          end
          put 'activate' do
            connection = find_connection!(params[:connection_id])

            connection.activate!

            present connection, with: ::API::Entities::Ai::ActiveContext::Connection
          end

          desc 'Deactivate an ActiveContext connection' do
            success ::API::Entities::Ai::ActiveContext::Connection
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' },
              { code: 404, message: '404 Not found' }
            ]
            tags %w[active_context]
          end
          params do
            optional :connection_id, type: Integer, desc: 'Connection ID (defaults to active connection)'
          end
          put 'deactivate' do
            connection = find_connection!(params[:connection_id])

            connection.deactivate!

            present connection, with: ::API::Entities::Ai::ActiveContext::Connection
          end
        end

        resources 'admin/active_context/collections' do
          desc 'Update collection options' do
            success ::API::Entities::Ai::ActiveContext::Collection
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' },
              { code: 404, message: '404 Not found' }
            ]
            tags %w[active_context]
          end
          params do
            requires :id, types: [String, Integer], desc: 'Collection name or ID'
            at_least_one_of :queue_shard_count, :queue_shard_limit
            optional :queue_shard_count, type: Integer, desc: 'Number of queue shards'
            optional :queue_shard_limit, type: Integer, desc: 'Queue shard limit'
            optional :connection_id, type: Integer, desc: 'Connection ID (defaults to active connection)'
          end
          put ':id' do
            connection = find_connection!(params[:connection_id])
            collection = find_collection!(connection, params[:id])

            options_to_update = {
              queue_shard_count: params[:queue_shard_count],
              queue_shard_limit: params[:queue_shard_limit]
            }.compact

            collection.update_options!(options_to_update)

            present collection, with: ::API::Entities::Ai::ActiveContext::Collection
          end
        end

        resources 'admin/active_context/code/enabled_namespaces' do
          desc 'Update enabled namespace state' do
            success ::API::Entities::Ai::ActiveContext::Code::EnabledNamespace
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' },
              { code: 404, message: '404 Not found' }
            ]
            tags %w[active_context]
          end
          params do
            requires :namespace_id, types: [String, Integer], desc: 'Namespace path or ID'
            requires :state, type: String, values: %w[pending ready], desc: 'State (pending or ready)'
            optional :connection_id, type: Integer, desc: 'Connection ID (defaults to active connection)'
          end
          put do
            connection = find_connection!(params[:connection_id])
            namespace = find_namespace!(params[:namespace_id])
            enabled_namespace = find_enabled_namespace!(connection, namespace)

            case params[:state]
            when 'pending'
              enabled_namespace.pending!
            when 'ready'
              enabled_namespace.ready!
            end

            present enabled_namespace, with: ::API::Entities::Ai::ActiveContext::Code::EnabledNamespace
          end
        end
      end
    end
  end
end
