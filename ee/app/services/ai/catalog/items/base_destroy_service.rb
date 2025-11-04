# frozen_string_literal: true

module Ai
  module Catalog
    module Items
      class BaseDestroyService < Ai::Catalog::BaseService
        def initialize(project:, current_user:, params:)
          @item = params[:item]
          super
        end

        def execute
          return error_no_permissions unless allowed?
          return error_no_item unless valid?

          result = force_hard_delete? ? perform_hard_delete : perform_soft_delete

          track_deletion_event if result.success?

          result
        end

        private

        attr_reader :item

        def allowed?
          allowed = super && Ability.allowed?(current_user, :delete_ai_catalog_item, item)

          if force_hard_delete? # rubocop:disable Style/IfUnlessModifier -- Improves readability
            allowed &= Ability.allowed?(current_user, :force_hard_delete_ai_catalog_item, item)
          end

          allowed
        end

        def valid?
          !!item
        end

        def success
          ServiceResponse.success
        end

        def error_no_item
          error('Item not found')
        end

        def perform_hard_delete
          item.class.transaction do
            item.consumers.each_batch do |batch|
              batch.delete_all
            end
            item.destroy
          end

          ServiceResponse.success
        end

        def perform_soft_delete
          result = destroy_item_consumer
          return result if result.error?

          destroy_item_with_strategy
        end

        def destroy_item_consumer
          consumer = project.configured_ai_catalog_items.for_item(item).first

          return ServiceResponse.success unless consumer

          Ai::Catalog::ItemConsumers::DestroyService.new(consumer, current_user).execute
        end

        def destroy_item_with_strategy
          success = if item.consumers.any? || item.dependents.any?
                      item.soft_delete
                    else
                      item.destroy
                    end

          success ? ServiceResponse.success : error(item.errors.full_messages)
        end

        def force_hard_delete?
          params[:force_hard_delete] == true
        end

        def track_deletion_event
          track_ai_item_events('delete_ai_catalog_item', { label: item.item_type })
        end
      end
    end
  end
end
