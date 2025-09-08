# frozen_string_literal: true

module RemoteDevelopment
  module WorkspacesServerOperations
    module AuthorizeUserAccess
      class Authorizer
        include Messages
        extend Gitlab::Fp::MessageSupport

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.authorize(context)
          context => {
            user_id: Integer => user_id,
            workspace: workspace,
            port: String => port
          }

          # TODO: check if port is available in processed_devfile

          unless workspace.user_id == user_id
            return Gitlab::Fp::Result.err(
              WorkspaceAuthorizeUserAccessFailed.new({ status: Status::NOT_AUTHORIZED })
            )
          end

          Gitlab::Fp::Result.ok(
            context.merge(
              response_payload: {
                status: Status::AUTHORIZED,
                info: {
                  port: port,
                  workspace_id: workspace.id
                }
              }
            )
          )
        end
      end
    end
  end
end
