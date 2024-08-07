# frozen_string_literal: true

module EE
  module Ci
    module BuildPolicy
      extend ActiveSupport::Concern

      prepended do
        # Authorize access to the troubleshoot job to Cloud Connector Service
        condition(:troubleshoot_job_cloud_connector_authorized) do
          next true if troubleshoot_job_connection.allowed_for?(@user)

          next false unless troubleshoot_job_connection.free_access?

          if ::Gitlab::Saas.feature_available?(:duo_chat_on_saas) # check if we are on SaaS
            user.any_group_with_ga_ai_available?(:troubleshoot_job)
          else
            License.feature_available?(:ai_features)
          end
        end

        # Authorize access to Troubleshoot Job
        condition(:troubleshoot_job_with_ai_authorized) do
          ::Gitlab::Llm::Chain::Utils::ChatAuthorizer.resource(
            resource: subject.project,
            user: @user
          ).allowed?
        end

        condition(:troubleshoot_job_licensed, scope: :subject) do
          subject.project.licensed_feature_available?(:troubleshoot_job)
        end

        rule do
          can?(:read_build_trace) &
            troubleshoot_job_licensed &
            troubleshoot_job_cloud_connector_authorized &
            troubleshoot_job_with_ai_authorized
        end.enable(:troubleshoot_job_with_ai)

        def troubleshoot_job_connection
          CloudConnector::AvailableServices.find_by_name(:troubleshoot_job)
        end
      end
    end
  end
end
