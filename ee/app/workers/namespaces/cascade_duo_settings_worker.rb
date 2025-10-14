# frozen_string_literal: true

module Namespaces
  class CascadeDuoSettingsWorker
    include ApplicationWorker
    extend ActiveSupport::Concern

    feature_category :ai_abstraction_layer

    idempotent!
    deduplicate :until_executed, if_deduplicated: :reschedule_once
    urgency :low
    data_consistency :delayed
    loggable_arguments 0
    worker_resource_boundary :memory
    defer_on_database_health_signal :gitlab_main, [:namespace_settings, :project_settings], 1.minute

    def perform(group_id, setting_attributes)
      group = Group.find_by_id(group_id)

      ::Ai::CascadeDuoSettingsService.new(setting_attributes).cascade_for_group(group)
    end
  end
end
