# frozen_string_literal: true

module WorkItems
  module Widgets
    class Weight < Base
      include Gitlab::Utils::StrongMemoize

      class << self
        def quick_action_commands
          [:weight, :clear_weight]
        end

        def quick_action_params
          [:weight]
        end

        def sorting_keys
          {
            weight_asc: {
              description: 'Weight by ascending order.',
              experiment: { milestone: '17.11' }
            },
            weight_desc: {
              description: 'Weight by descending order.',
              experiment: { milestone: '17.11' }
            }
          }
        end
      end

      def weight
        return unless widget_options[:editable]

        work_item.weight
      end

      def rolled_up_weight
        return unless widget_options[:rollup] && rolled_up_weight_by_state.present?

        rolled_up_weight_by_state.sum { |_, weight| weight }
      end

      def rolled_up_completed_weight
        return unless widget_options[:rollup] && rolled_up_weight_by_state.present?

        rolled_up_weight_by_state.fetch(WorkItem.available_states[:closed], 0)
      end

      private

      def rolled_up_weight_by_state
        # We cannot use `#sum(:weight)` because ActiveRecord returns 0 when PG returns NULL.
        # We need to distinguish between a sum of 0 and the absence of descendant weights.
        work_item.descendants
          .where(work_item_type_id: WorkItems::Type.default_issue_type.id)
          .group(:state_id)
          .pluck('state_id, SUM(weight)') # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- We only have a limited number of states
          .to_h
          .compact
      end
      strong_memoize_attr :rolled_up_weight_by_state
    end
  end
end
