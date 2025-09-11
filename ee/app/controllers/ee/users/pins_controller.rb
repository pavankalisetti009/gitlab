# frozen_string_literal: true

module EE
  module Users
    module PinsController
      extend ::Gitlab::Utils::Override

      private

      override :track_unpin_event
      def track_unpin_event(panel, item)
        super

        experiment(:default_pinned_nav_items, actor: current_user).track(:unpin_menu_item, label: item)
      end

      override :track_pin_event
      def track_pin_event(panel, item)
        super

        experiment(:default_pinned_nav_items, actor: current_user).track(:pin_menu_item, label: item)
      end
    end
  end
end
