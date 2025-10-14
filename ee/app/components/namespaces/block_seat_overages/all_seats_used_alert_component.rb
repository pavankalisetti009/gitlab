# frozen_string_literal: true

module Namespaces
  module BlockSeatOverages
    class AllSeatsUsedAlertComponent < ViewComponent::Base
      def initialize(context:, current_user:)
        @root_namespace = context&.root_ancestor
        @current_user = current_user
      end

      private

      attr_reader :root_namespace, :current_user

      def render?
        !user_dismissed_alert?
      end

      def user_dismissed_alert?
        current_user.dismissed_callout_for_group?(
          feature_name: EE::Users::GroupCalloutsHelper::ALL_SEATS_USED_ALERT,
          group: root_namespace
        )
      end
    end
  end
end
