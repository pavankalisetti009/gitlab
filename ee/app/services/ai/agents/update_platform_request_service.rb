# frozen_string_literal: true

module Ai
  module Agents
    class UpdatePlatformRequestService < BaseService
      def initialize(user)
        @current_user = user
      end

      def execute
        callout = current_user.find_or_initialize_callout('duo_agent_platform_requested')
        return ServiceResponse.success(message: 'Access already requested') if callout.persisted?

        if callout.save
          ::Ai::Setting.increment_counter(:duo_agent_platform_request_count, ::Ai::Setting.instance.id)

          ServiceResponse.success
        else
          ServiceResponse.error(message: callout.errors.full_messages.to_sentence)
        end
      end
    end
  end
end
