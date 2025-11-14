# frozen_string_literal: true

module Ai
  module Catalog
    module ItemConsumers
      class CreateService < ::BaseContainerService
        include EventsTracking

        def execute
          return validation_error if validation_error

          add_service_account_result = create_service_account_result = create_item_consumer_result = nil
          project_member = item_consumer = service_account_response = nil

          ApplicationRecord.transaction do
            create_service_account_result, service_account_response = create_service_account
            raise ActiveRecord::Rollback if create_service_account_result == :failure

            create_item_consumer_result, item_consumer = create_item_consumer(service_account_response)
            raise ActiveRecord::Rollback if create_item_consumer_result == :failure

            add_service_account_result, project_member = add_service_account_to_project
            raise ActiveRecord::Rollback if add_service_account_result == :failure
          end

          return error(service_account_response) if create_service_account_result == :failure
          return error_creating(project_member) if add_service_account_result == :failure
          return error_creating(item_consumer) if create_item_consumer_result == :failure

          track_item_consumer_event(item_consumer, 'create_ai_catalog_item_consumer')
          send_audit_events(item_consumer, audit_event_name)
          ServiceResponse.success(payload: { item_consumer: item_consumer })
        end

        private

        strong_memoize_attr def validation_error
          return error_not_project_or_top_level_group unless for_project_or_top_level_group?
          return error_no_permissions unless allowed?
          return error_parent_item_consumer_not_passed if project_flow_without_parent_item_consumer?

          error_flow_triggers_must_be_for_project if flow_triggers_not_for_project?
        end

        def audit_event_name
          "enable_ai_catalog_#{item.item_type}"
        end

        def parent_item_consumer_service_account
          parent_item_consumer&.service_account
        end

        def parent_item_consumer
          params[:parent_item_consumer]
        end

        def project_flow_without_parent_item_consumer?
          return false unless ai_catalog_flows_enabled?

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

          item_consumer = ::Ai::Catalog::ItemConsumer.create(params)
          return [:success, item_consumer] if item_consumer.persisted?

          [:failure, item_consumer]
        end

        def create_service_account
          # In case we don't need to create the service account (because this is not group level), we should return
          # no_op, and continue creating the item consumer.
          return [:no_op, nil] if group.nil?

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
            return [:failure, response.message]
          end

          [:success, response.payload[:user]]
        end

        def add_service_account_to_project
          return [:no_op, nil] unless ai_catalog_flows_enabled?

          return [:no_op, nil] unless project_container? && (item.flow? || item.third_party_flow?)

          project_member = project.team.add_member(
            parent_item_consumer_service_account, Member::DEVELOPER, current_user:
          )

          return [:failure, project_member] if project_member.nil? || !project_member.persisted?

          [:success, project_member]
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

        def for_project_or_top_level_group?
          project || group&.root?
        end

        def item
          params[:item]
        end

        def error_creating(record)
          return error('Failed to create item consumer') if record.nil?

          error(record.errors.full_messages.presence || 'Failed to create item consumer')
        end

        def allowed?
          return false if group_container? && !Ability.allowed?(current_user, :create_service_account, group)

          Ability.allowed?(current_user, :admin_ai_catalog_item_consumer, container) &&
            Ability.allowed?(current_user, :read_ai_catalog_item, item)
        end

        def ai_catalog_flows_enabled?
          Feature.enabled?(:ai_catalog_flows, container)
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

        def error_not_project_or_top_level_group
          error('Item can only be enabled in projects or top-level groups')
        end
      end
    end
  end
end
