# frozen_string_literal: true

module Clusters
  module Agents
    module AutoFlow
      class << self
        def issue_events_enabled?(work_item_id)
          # We only want project-scoped issue events for now.
          work_item = ::WorkItem.find_by_id(work_item_id)
          return false unless work_item
          return false unless work_item.project.present?
          return false unless work_item.work_item_type.issue?

          actor = work_item.project

          autoflow_enabled?(actor) && Feature.enabled?(:autoflow_issue_events_enabled, actor)
        end

        private

        def autoflow_enabled?(actor)
          ::Gitlab::Kas.enabled? && Feature.enabled?(:autoflow_enabled, actor)
        end
      end
    end
  end
end
