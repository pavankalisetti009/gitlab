# frozen_string_literal: true

module Notifications
  module TargetedMessages
    class CreateService < BaseService
      def execute
        parse_namespaces

        @targeted_message = Notifications::TargetedMessage.new(target_message_params)

        if @targeted_message.save
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
              s_('TargetedMessages|Targeted message was successfully created. But %{invalid_namespace_ids_message}'),
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
