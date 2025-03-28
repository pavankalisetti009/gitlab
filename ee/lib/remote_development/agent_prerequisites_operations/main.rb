# frozen_string_literal: true

module RemoteDevelopment
  module AgentPrerequisitesOperations
    class Main
      include Messages
      extend Gitlab::Fp::MessageSupport

      # @param [Hash] context
      # @return [Hash]
      # @raise [Gitlab::Fp::UnmatchedResultError]
      def self.main(context)
        initial_result = Gitlab::Fp::Result.ok(context)

        result =
          initial_result
            .map(ResponseBuilder.method(:build))
            .map(
              # As the final step, return the response_payload content in a WorkspaceReconcileSuccessful message
              ->(context) do
                AgentPrerequisitesSuccessful.new(context.fetch(:response_payload))
              end
            )

        case result
        in { ok: AgentPrerequisitesSuccessful => message }
          # Type-check the payload before returning it
          message.content => {
            shared_namespace: String
          }
          { status: :success, payload: message.content }
        else
          raise Gitlab::Fp::UnmatchedResultError.new(result: result)
        end
      end
    end
  end
end
