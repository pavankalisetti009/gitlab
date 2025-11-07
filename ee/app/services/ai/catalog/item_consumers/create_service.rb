# frozen_string_literal: true

module Ai
  module Catalog
    module ItemConsumers
      class CreateService < ::BaseContainerService
        include InternalEventsTracking

        def execute
          return error_no_permissions unless allowed?
          return error_parent_item_consumer_not_passed if project_flow_without_parent_item_consumer?
          return error_flow_triggers_must_be_for_project if flow_triggers_not_for_project?

          item_consumer = service_account_creation_result = nil

          ApplicationRecord.transaction do
            service_account_creation_result = create_service_account
            raise ActiveRecord::Rollback if service_account_creation_result.error?

            item_consumer = create_item_consumer(service_account_creation_result.payload[:user])
            raise ActiveRecord::Rollback unless item_consumer.persisted?
          end

          return error_service_account(service_account_creation_result) if service_account_creation_result.error?

          if item_consumer.persisted?
            track_item_consumer_event(item_consumer, 'create_ai_catalog_item_consumer')
            ServiceResponse.success(payload: { item_consumer: item_consumer })
          else
            error_creating(item_consumer)
          end
        end

        private

        def parent_item_consumer_service_account
          parent_item_consumer&.service_account
        end

        def parent_item_consumer
          params[:parent_item_consumer]
        end

        def project_flow_without_parent_item_consumer?
          (item.flow? || item.third_party_flow?) && project.present? && parent_item_consumer.nil?
        end

        def flow_triggers_not_for_project?
          params[:trigger_types] && project.nil?
        end

        def create_item_consumer(service_account)
          # The enabled setting is not currently used, so always set new records as enabled.
          # https://gitlab.com/gitlab-org/gitlab/-/issues/553912#note_2706802395
          params.merge!(project: project, group: group, service_account: service_account, enabled: true)
          prepare_trigger_params

          ::Ai::Catalog::ItemConsumer.create(params)
        end

        def create_service_account
          # In case we don't need to create the service account (because this is not group level, or because the user
          # does not have the right permissions), we should return no_op, and continue creating the item consumer.
          # In a future MR we will prevent creating a group level item consumer without a service account, in which case
          # if there is a permission error an error will be returned.
          no_op = ServiceResponse.new(status: :no_op)
          return no_op if group.nil?
          return no_op unless Ability.allowed?(current_user, :create_service_account, group)

          service_account_params = {
            namespace_id: group.id,
            name: item.name,
            username: service_account_username,
            organization_id: group.organization_id
          }

          # TODO: Handle duplicate username (possible with my-flow a-group-name and my-flow-a group-name)
          # We can handle this in the future, when we add an optional service_account_name param
          # https://gitlab.com/gitlab-org/gitlab/-/issues/579435
          response = ::Namespaces::ServiceAccounts::CreateService.new(
            current_user,
            service_account_params
          ).execute

          if response.error?
            log_error("Failed to create service account with name '#{service_account_username}': #{response.message}")
          end

          response
        end

        def prepare_trigger_params
          return if params[:trigger_types].nil?

          trigger_types = params.delete(:trigger_types).map { |type| ::Ai::FlowTrigger::EVENT_TYPES[type.to_sym] }

          params[:flow_trigger_attributes] = {
            project: project,
            user: parent_item_consumer_service_account,
            description: "Auto-created triggers for #{item.name}",
            event_types: trigger_types
          }
        end

        def service_account_username
          "ai-#{item.name}-#{group.name}".parameterize
        end

        def item
          params[:item]
        end

        def error_creating(item_consumer)
          error(item_consumer.errors.full_messages.presence || 'Failed to create item consumer')
        end

        def allowed?
          Ability.allowed?(current_user, :admin_ai_catalog_item_consumer, container) &&
            Ability.allowed?(current_user, :read_ai_catalog_item, item)
        end

        def error(message)
          ServiceResponse.error(message: Array(message))
        end

        def error_service_account(service_account_creation_result)
          error(service_account_creation_result.message)
        end

        def error_no_permissions
          error('Item does not exist, or you have insufficient permissions')
        end

        def error_flow_triggers_must_be_for_project
          error("Flow triggers can only be set for projects")
        end

        def error_parent_item_consumer_not_passed
          error("Project item must have a parent item consumer")
        end
      end
    end
  end
end
