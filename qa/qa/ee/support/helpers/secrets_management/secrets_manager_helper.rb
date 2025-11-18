# frozen_string_literal: true

module QA
  module EE
    module Support
      module Helpers
        module SecretsManagement
          module SecretsManagerHelper
            # Deprovisions a secrets manager for a project via GraphQL
            # This is a temporary solution until UI deprovisioning is implemented
            #
            # @param project [QA::Resource::Project] The project to deprovision secrets manager for
            # @return [Hash] The GraphQL response
            def deprovision_secrets_manager(project)
              mutation = <<~GRAPHQL
                mutation {
                  projectSecretsManagerDeprovision(input: { projectPath: "#{project.full_path}" }) {
                    projectSecretsManager {
                      status
                      project {
                        id
                        fullPath
                      }
                    }
                    errors
                  }
                }
              GRAPHQL

              response = QA::Support::API.post(
                "#{QA::Runtime::Scenario.gitlab_address}/api/graphql",
                { query: mutation },
                headers: {
                  Authorization: "Bearer #{QA::Runtime::User::Store.default_api_client.personal_access_token}"
                }
              )

              parsed_response = JSON.parse(response.body, symbolize_names: true)
              mutation_response = parsed_response.dig(:data, :projectSecretsManagerDeprovision)

              QA::Runtime::Logger.info("Successfully initiated deprovisioning for project: #{project.full_path}")

              mutation_response
            end

            # Checks if OpenBao instance is healthy and reachable via GraphQL
            # This uses the GraphQL resolver which requires authentication
            #
            # @return [Boolean] true if OpenBao is healthy, false otherwise
            def openbao_healthy?
              query = <<~GRAPHQL
                query {
                  openbaoHealth
                }
              GRAPHQL

              response = QA::Support::API.post(
                "#{QA::Runtime::Scenario.gitlab_address}/api/graphql",
                { query: query },
                headers: {
                  Authorization: "Bearer #{QA::Runtime::User::Store.default_api_client.personal_access_token}"
                }
              )

              parsed_response = JSON.parse(response.body, symbolize_names: true)

              query_response = parsed_response.dig(:data, :openbaoHealth)

              QA::Runtime::Logger.info("Openbao instance available")

              query_response
            end
          end
        end
      end
    end
  end
end
