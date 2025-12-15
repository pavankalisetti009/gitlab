# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class SyncFoundationalFlowsService
        def initialize(container, current_user: nil)
          @container = container
          @current_user = current_user
        end

        def execute
          return remove_all_flows unless foundational_flows_enabled?

          sync_flows
        end

        private

        attr_reader :container, :current_user

        def foundational_flows_enabled?
          case container
          when Project
            container.project_setting&.duo_foundational_flows_enabled
          when Group, Namespace
            container.namespace_settings&.duo_foundational_flows_enabled
          else
            false
          end
        end

        def enabled_flow_catalog_item_ids
          container.enabled_flow_catalog_item_ids
        end

        def sync_flows
          target_ids = enabled_flow_catalog_item_ids

          target_ids.each do |catalog_item_id|
            item = Item.find(catalog_item_id)
            create_consumer_for_catalog_item(item)
          rescue ActiveRecord::RecordNotFound => e
            ::Gitlab::ErrorTracking.track_exception(
              e,
              catalog_item_id: catalog_item_id,
              container_id: container.id
            )
          end

          remove_consumers_not_in(target_ids)
        end

        def create_consumer_for_catalog_item(item)
          return unless should_create_consumer?(item)
          return unless authorized_to_create_consumer?(item)

          result = create_or_find_consumer(item)
          consumer = extract_consumer_from_result(result, item)

          create_trigger_if_needed(consumer, item) if consumer

          result
        end

        def should_create_consumer?(item)
          return true unless container.is_a?(Project)

          parent_consumer = find_existing_consumer(item, container.root_ancestor)
          parent_consumer.present?
        end

        def authorized_to_create_consumer?(item)
          return false unless current_user

          Ability.allowed?(current_user, :admin_ai_catalog_item_consumer, container) &&
            Ability.allowed?(current_user, :read_ai_catalog_item, item)
        end

        def create_or_find_consumer(item)
          params = build_consumer_params(item)

          ::Ai::Catalog::ItemConsumers::CreateService.new(
            container: container,
            current_user: current_user,
            params: params
          ).execute
        end

        def build_consumer_params(item)
          params = { item: item }

          if container.is_a?(Project) && item.flow?
            parent_consumer = find_existing_consumer(item, container.root_ancestor)

            params[:parent_item_consumer] = parent_consumer if parent_consumer
          end

          params
        end

        def extract_consumer_from_result(result, item)
          return result.payload[:item_consumer] if result.success?
          return find_existing_consumer(item, container) if item_already_configured?(result)

          nil
        end

        def item_already_configured?(result)
          result.error? && result.message.include?("Item already configured")
        end

        def find_existing_consumer(item, container)
          container.configured_ai_catalog_items.find { |c| c.ai_catalog_item_id == item.id }
        end

        def create_trigger_if_needed(consumer, item)
          return unless container.is_a?(Project)

          create_trigger_for_consumer(consumer, item)
        end

        def create_trigger_for_consumer(consumer, item)
          service_account = extract_service_account(consumer)
          return unless service_account

          trigger_params = build_trigger_params(service_account, consumer, item)
          return unless trigger_params.present?

          ::Ai::FlowTriggers::CreateService.new(
            project: container,
            current_user: current_user
          ).execute(trigger_params)
        end

        def extract_service_account(consumer)
          if consumer.project.present?
            consumer.parent_item_consumer&.service_account
          else
            consumer.service_account
          end
        end

        def build_trigger_params(service_account, consumer, item)
          event_types = fetch_event_type_for_flow(item.foundational_flow_reference, service_account)
          return if event_types.empty?

          {
            user_id: service_account.id,
            description: "Foundational flow trigger for #{item.name}",
            ai_catalog_item_consumer_id: consumer.id,
            event_types: event_types
          }
        end

        def remove_consumers_not_in(catalog_item_ids)
          ids_to_remove = foundational_flow_ids - catalog_item_ids

          container.remove_foundational_flow_consumers(ids_to_remove)
        end

        def remove_all_flows
          container.remove_foundational_flow_consumers(foundational_flow_ids)
        end

        def foundational_flow_ids
          Item.foundational_flow_ids
        end

        def fetch_event_type_for_flow(foundational_flow_reference, service_account)
          flow_definition = ::Ai::DuoWorkflows::WorkflowDefinition[foundational_flow_reference]
          return [] unless flow_definition.present? && flow_definition.triggers.present?

          flow_definition.triggers.reject { |event| trigger_exists?(service_account, event) }
        end

        def trigger_exists?(service_account, event)
          event_type = ::Ai::FlowTrigger::EVENT_TYPES.key(event)
          return false unless event_type

          container.ai_flow_triggers.triggered_on(event_type).by_users([service_account]).exists?
        end
      end
    end
  end
end
