# frozen_string_literal: true

module Ai
  module FlowTriggers
    class UpdateService < BaseService
      attr_reader :project, :current_user, :resource, :flow_trigger

      def initialize(project:, current_user:, trigger:)
        @project = project
        @current_user = current_user
        @trigger = trigger
      end

      def execute(params)
        unless user_is_authorized_to_service_account?(params)
          return ServiceResponse.error(message: 'You are not authorized to use this service account in this project')
        end

        @trigger.update(params)

        if @trigger.valid?
          ServiceResponse.success(payload: @trigger)
        else
          ServiceResponse.error(message: @trigger.errors.full_messages.to_sentence)
        end
      end
    end
  end
end
