# frozen_string_literal: true

module API
  module RemoteDevelopment
    module Internal
      module Agents
        module Agentw
          class ServerConfig < ::API::Base
            before do
              authenticate_gitlab_kas_request!
            end

            helpers ::API::Helpers::KasHelpers

            namespace "internal" do
              namespace "agents" do
                namespace "agentw" do
                  desc "server_config" do
                    detail "Returns configuration for Workspaces HTTP Server."
                    tags ["oauth_applications"]
                    success code: 200, message: "Server config retrieved successfully"
                  end
                  get "/server_config", feature_category: :workspaces, urgency: :low do
                    response = ::RemoteDevelopment::CommonService.execute(
                      domain_main_class: ::RemoteDevelopment::WorkspacesServerOperations::ServerConfig::Main,
                      domain_main_class_args: { request: request }
                    )

                    # NOTE: There's currently no way an error can be returned other than an unexpected raised
                    #       exception, so we assume success.
                    status 200

                    response.payload
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
