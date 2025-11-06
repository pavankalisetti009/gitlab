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

          params.merge!(project:, group:, parent_item_consumer:)
          # The enabled setting is not currently used, so always set new records as enabled.
          # https://gitlab.com/gitlab-org/gitlab/-/issues/553912#note_2706802395
          params[:enabled] = true
          prepare_trigger_params
          item_consumer = ::Ai::Catalog::ItemConsumer.new(params)

          if item_consumer.save
            track_item_consumer_event(item_consumer, 'create_ai_catalog_item_consumer')
            ServiceResponse.success(payload: { item_consumer: item_consumer })
          else
            error_creating(item_consumer)
          end
        end

        private

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
