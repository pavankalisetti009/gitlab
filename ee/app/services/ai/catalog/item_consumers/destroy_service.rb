# frozen_string_literal: true

module Ai
  module Catalog
    module ItemConsumers
      class DestroyService
        include EventsTracking

        def initialize(item_consumer, current_user)
          @current_user = current_user
          @item_consumer = item_consumer
        end

        def execute
          return error_no_permissions unless allowed?

          error_messages = nil

          ApplicationRecord.transaction do
            successfully_deleted, error_messages = remove_service_account_from_project
            raise ActiveRecord::Rollback unless successfully_deleted

            successfully_deleted, error_messages = delete_service_account
            raise ActiveRecord::Rollback unless successfully_deleted

            successfully_deleted, error_messages = delete_item_consumer
            raise ActiveRecord::Rollback unless successfully_deleted
          end

          return error(error_messages) unless error_messages.nil?

          track_item_consumer_event(item_consumer, 'delete_ai_catalog_item_consumer', additional_properties: nil)
          send_audit_events(item_consumer, audit_event_name)
          ServiceResponse.success(payload: { item_consumer: item_consumer })
        end

        private

        attr_reader :current_user, :item_consumer

        def audit_event_name
          "disable_ai_catalog_#{item_consumer.item.item_type}"
        end

        def allowed?
          Ability.allowed?(current_user, :admin_ai_catalog_item_consumer, item_consumer)
        end

        def delete_item_consumer
          if item_consumer.destroy
            [true, nil]
          else
            [false, item_consumer.errors.full_messages]
          end
        end

        def remove_service_account_from_project
          service_account_id = item_consumer.parent_item_consumer&.service_account_id
          return [true, nil] if service_account_id.nil? || item_consumer.project.nil?

          member = item_consumer.project.team.find_member(service_account_id)

          return [true, nil] if member.nil?

          Members::DestroyService.new(current_user).execute(member)

          return [true, nil] if member.destroyed?

          errors = member.errors.full_messages.map { |err| "Service account membership: #{err}" }

          [false, errors]
        end

        def delete_service_account
          return [true, nil] unless item_consumer.service_account

          response = ::Namespaces::ServiceAccounts::DeleteService
            .new(current_user, item_consumer.service_account)
            .execute

          return [false, [response.message]] if response.error?

          [true, nil]
        end

        def error_no_permissions
          error('You have insufficient permissions to delete this item consumer')
        end

        def error(message)
          ServiceResponse.error(message: Array(message))
        end
      end
    end
  end
end
