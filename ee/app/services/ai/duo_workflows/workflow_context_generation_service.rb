# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowContextGenerationService
      def initialize(current_user:, organization:, workflow_definition: nil, container: nil)
        @current_user = current_user
        @container = container
        @organization = organization
        @workflow_definition = workflow_definition
      end

      def generate_oauth_token
        ::Ai::DuoWorkflows::CreateOauthAccessTokenService.new(
          current_user: current_user,
          organization: organization,
          workflow_definition: workflow_definition
        ).execute
      end

      def generate_composite_oauth_token
        ::Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService.new(
          current_user: current_user,
          organization: organization
        ).execute
      end

      def generate_workflow_token
        ::Ai::DuoWorkflow::DuoWorkflowService::Client.new(
          duo_workflow_service_url: Gitlab::DuoWorkflow::Client.url(user: current_user),
          current_user: current_user,
          secure: Gitlab::DuoWorkflow::Client.secure?
        ).generate_token
      end

      def generate_oauth_token_with_composite_identity_support
        if composite_identity_enabled?
          generate_composite_oauth_token
        else
          generate_oauth_token
        end
      end

      def use_service_account?
        composite_identity_enabled?
      end

      private

      attr_reader :current_user, :container, :organization, :workflow_definition

      def composite_identity_enabled?
        Feature.enabled?(:duo_workflow_use_composite_identity, current_user)
      end
    end
  end
end
