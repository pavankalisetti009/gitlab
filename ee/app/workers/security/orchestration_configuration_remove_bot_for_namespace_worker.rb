# frozen_string_literal: true

module Security
  class OrchestrationConfigurationRemoveBotForNamespaceWorker
    include ApplicationWorker

    PROJECTS_BATCH_SYNC_DELAY = 1.second

    feature_category :security_policy_management
    data_consistency :sticky
    urgency :low
    idempotent!

    concurrency_limit -> { 200 }

    def perform(namespace_id, current_user_id)
      namespace = Namespace.find_by_id(namespace_id)
      return unless namespace

      return unless User.id_exists?(current_user_id)

      project_ids = namespace.security_orchestration_policy_configuration.all_project_ids

      Security::OrchestrationConfigurationRemoveBotWorker.bulk_perform_in_with_contexts(
        PROJECTS_BATCH_SYNC_DELAY,
        project_ids,
        arguments_proc: ->(project_id) { [project_id, current_user_id] },
        context_proc: ->(namespace) { { namespace: namespace } }
      )
    end
  end
end
