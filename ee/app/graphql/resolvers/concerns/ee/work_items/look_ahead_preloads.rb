# frozen_string_literal: true

module EE
  module WorkItems
    module LookAheadPreloads
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      private

      override :preloads
      def preloads
        super.merge(
          promoted_to_epic_url: :work_item_transition
        )
      end

      override :widget_preloads
      def widget_preloads
        super.merge(
          [:widgets, :feature_flags] => { feature_flags: :project },
          [:widgets, :iteration] => { iteration: :group },
          [:widgets, :progress] => :progress,
          [:widgets, :status] => { current_status: :custom_status },
          [:widgets, :test_reports] => :test_reports,
          [:widgets, :verification_status] => { requirement: :recent_test_reports },
          [:widgets, :weight] => :weights_source
        )
      end

      def unconditional_includes
        [
          *super,
          :sync_object,
          :namespace
        ]
      end
    end
  end
end
