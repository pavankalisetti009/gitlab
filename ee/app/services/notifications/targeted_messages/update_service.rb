# frozen_string_literal: true

module Notifications
  module TargetedMessages
    class UpdateService < BaseService
      def initialize(targeted_message, params)
        super(params)

        @targeted_message = targeted_message
      end

      def execute
        parse_namespaces

        if @targeted_message.update(target_message_params)
          handle_success
        else
          handle_failure
        end
      end

      private

      def handle_success
        if partial_success?
          ServiceResponse.error(
            message: format(
              s_('TargetedMessages|Targeted message was successfully updated. But %{invalid_namespace_ids_message}'),
              invalid_namespace_ids_message: parsed_namespaces[:message]
            ),
            payload: targeted_message,
            reason: FOUND_INVALID_NAMESPACES
          )
        else
          success
        end
      end
    end
  end
end
