# frozen_string_literal: true

module VirtualRegistries
  class DestroyLocalUpstreamsWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :sticky
    feature_category :virtual_registry
    urgency :low
    idempotent!
    defer_on_database_health_signal :gitlab_main, [:virtual_registries_packages_maven_upstreams], 5.minutes

    UPSTREAM_CLASSES = [
      ::VirtualRegistries::Packages::Maven::Upstream
    ].freeze

    EVENT_MAPPING = {
      ::Projects::ProjectDeletedEvent => {
        class: Project,
        id_field: :project_id
      },
      ::Groups::GroupDeletedEvent => {
        class: Group,
        id_field: :group_id
      }
    }.freeze

    def handle_event(event)
      return unless EVENT_MAPPING.key?(event.class)

      id = event.data[id_field(event.class)]

      return unless id.present?

      global_id = model_class(event.class).new(id:).to_global_id.to_s

      UPSTREAM_CLASSES.each do |klass|
        klass.for_url(global_id).find_each(&:destroy_and_sync_positions) # rubocop:disable CodeReuse/ActiveRecord -- specific code for this worker that will not be re-used
      end
    end

    def id_field(klass)
      EVENT_MAPPING.dig(klass, :id_field)
    end

    def model_class(klass)
      EVENT_MAPPING.dig(klass, :class)
    end
  end
end
