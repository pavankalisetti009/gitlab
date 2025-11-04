# frozen_string_literal: true

module API
  module RemoteDevelopment
    module Internal
      module Agents
        module Agentw
          class AgentInfo < ::API::Base
            helpers ::API::Helpers::KasHelpers

            before do
              authenticate_gitlab_kas_request!
            end

            namespace "internal" do
              namespace "agents" do
                namespace "agentw" do
                  desc "Gets agentw info" do
                    detail "Retrieves agent info for agentw for the given workspace token"
                    tags ["workspace_tokens"]
                    success code: 200, message: "Agentw info retrieved successfully"
                  end

                  get '/agent_info', feature_category: :workspaces, urgency: :low do
                    workspace_token = workspace_token_from_authorization_token

                    unauthorized! unless workspace_token

                    status 200

                    {
                      workspace_id: workspace_token.workspace.id
                    }
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
