# frozen_string_literal: true

module Graphql
  module Subscriptions
    module Security
      module PoliciesSyncUpdated
        module Helper
          def subscription_response
            subscription_channel = subscribe
            yield
            subscription_channel.mock_broadcasted_messages.first
          end

          def security_policies_sync_updated_subscription(policy_configuration, current_user)
            mock_channel = Graphql::Subscriptions::ActionCable::MockActionCable.get_mock_channel
            query = security_policies_sync_updated_subscription_query(policy_configuration)

            GitlabSchema.execute(query, context: { current_user: current_user, channel: mock_channel })

            mock_channel
          end

          private

          def security_policies_sync_updated_subscription_query(policy_configuration)
            <<~SUBSCRIPTION
              subscription {
                securityPoliciesSyncUpdated(policyConfigurationId: \"#{policy_configuration.to_global_id}\") {
                  projectsProgress
                  projectsTotal
                  failedProjects
                  mergeRequestsProgress
                  mergeRequestsTotal
                  inProgress
                }
              }
            SUBSCRIPTION
          end
        end
      end
    end
  end
end
