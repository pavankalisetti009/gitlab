# frozen_string_literal: true

module CloudConnector
  module SelfManaged
    class AvailableServiceData < BaseAvailableServiceData
      extend ::Gitlab::Utils::Override

      override :access_token
      def access_token(_resource = nil, **)
        # for SelfManaged instances we are using instance token synced from CustomersDot
        ::CloudConnector::ServiceAccessToken.active.last&.token
      end

      override :purchased?
      def purchased?(_namespace = nil)
        super(:instance)
      end
    end
  end
end
