# frozen_string_literal: true

module EE
  module Ci
    module BuildPolicy
      extend ActiveSupport::Concern

      prepended do
        # Authorize access to the troubleshoot job to Cloud Connector Service
        condition(:troubleshoot_job_cloud_connector_authorized) do
          @user&.allowed_to_use?(:troubleshoot_job)
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
      end
    end
  end
end
