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
          params = { item: item }

          if container.is_a?(Project) && item.flow?
            parent_consumer = container.namespace.configured_ai_catalog_items.for_item(item.id).first

            return if parent_consumer.nil?

            params[:parent_item_consumer] = parent_consumer
          end

          if current_user
            return unless Ability.allowed?(current_user, :admin_ai_catalog_item_consumer, container)
            return unless Ability.allowed?(current_user, :read_ai_catalog_item, item)
          end

          ::Ai::Catalog::ItemConsumers::CreateService.new(
            container: container,
            current_user: current_user,
            params: params
          ).execute
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
      end
    end
  end
end
