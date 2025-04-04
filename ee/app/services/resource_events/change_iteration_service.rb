# frozen_string_literal: true

module ResourceEvents
  class ChangeIterationService < ::ResourceEvents::BaseChangeTimeboxService
    attr_reader :iteration, :old_iteration_id, :automated, :triggered_by_work_item

    def initialize(resource, user, old_iteration_id:, automated: false, triggered_by_work_item: nil)
      super(resource, user)

      @resource = resource
      @user = user
      @iteration = resource&.iteration
      @old_iteration_id = old_iteration_id
      @automated = automated
      @triggered_by_work_item = triggered_by_work_item
    end

    def build_resource_args
      action = iteration.blank? ? :remove : :add

      super.merge({
        action: ResourceTimeboxEvent.actions[action],
        iteration_id: iteration.blank? ? old_iteration_id : iteration.id,
        automated: automated,
        triggered_by_id: triggered_by_work_item&.id
      })
    end

    private

    def track_event
      return unless resource.is_a?(WorkItem)

      Gitlab::UsageDataCounters::WorkItemActivityUniqueCounter.track_work_item_iteration_changed_action(author: user)
    end

    def create_event
      ResourceIterationEvent.create(build_resource_args)
    end
  end
end
