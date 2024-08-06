# frozen_string_literal: true

module Resolvers
  module CloudConnector
    class StatusResolver < BaseResolver
      type Types::CloudConnector::StatusType, null: false

      description 'Run a series of status checks for Cloud Connector features'

      def resolve
        return unless current_user
        return unless Feature.enabled?(:cloud_connector_status, current_user)
        return if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

        ::CloudConnector::StatusChecks::StatusService.new(user: current_user).execute
      end
    end
  end
end
