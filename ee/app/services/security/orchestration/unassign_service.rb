# frozen_string_literal: true

module Security
  module Orchestration
    class UnassignService < ::BaseContainerService
      include Gitlab::Utils::StrongMemoize

      def execute(delete_bot: true)
        return error(_('Policy project doesn\'t exist')) unless security_orchestration_policy_configuration

        old_policy_project = security_orchestration_policy_configuration.security_policy_management_project

        remove_bot(security_orchestration_policy_configuration) if delete_bot

        delete_configuration(security_orchestration_policy_configuration, old_policy_project) if delete_configuration?

        success
      end

      private

      delegate :security_orchestration_policy_configuration, to: :container

      def delete_configuration(configuration, old_policy_project)
        Security::DeleteOrchestrationConfigurationWorker.perform_async(
          configuration.id, current_user.id, old_policy_project.id)
      end

      def success
        ServiceResponse.success
      end

      def error(message)
        ServiceResponse.error(message: message)
      end

      def remove_bot(security_orchestration_policy_configuration)
        if project?
          Security::OrchestrationConfigurationRemoveBotWorker.perform_async(container.id, current_user.id)
        else
          remove_bot_for_namespace(security_orchestration_policy_configuration)
        end
      end

      def remove_bot_for_namespace(security_orchestration_policy_configuration)
        if namespace_worker_enabled?
          Security::OrchestrationConfigurationRemoveBotForNamespaceWorker.perform_async(container.id, current_user.id)
        else
          security_orchestration_policy_configuration.all_project_ids.each do |project_id|
            Security::OrchestrationConfigurationRemoveBotWorker.perform_async(project_id, current_user.id)
          end
        end
      end

      def namespace_worker_enabled?
        Feature.enabled?(:security_policy_bot_worker, container)
      end
      strong_memoize_attr :namespace_worker_enabled?

      def project?
        container.is_a?(Project)
      end
      strong_memoize_attr :project?

      def delete_configuration?
        project? || !namespace_worker_enabled?
      end
    end
  end
end
