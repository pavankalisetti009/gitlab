# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateCompositeOauthAccessTokenService
      include ::Services::ReturnServiceResponses
      include ::Gitlab::Utils::StrongMemoize

      CompositeIdentityEnforcedError = Class.new(StandardError)
      IncompleteOnboardingError = Class.new(StandardError)
      TOKEN_EXPIRES_IN = 1.hour

      def initialize(current_user:, organization:, scopes: nil, service_account: nil)
        @current_user = current_user
        @organization = organization
        @service_account = service_account || ai_settings.duo_workflow_service_account_user
        @scopes = (scopes || (::Gitlab::Auth::AI_WORKFLOW_SCOPES + [::Gitlab::Auth::MCP_SCOPE])) + dynamic_user_scope
      end

      def execute
        unless Feature.enabled?(:duo_workflow_use_composite_identity, @current_user)
          msg = 'Can not generate token to execute workflow in CI'
          return ServiceResponse.error(message: msg, reason: :feature_unavailable)
        end

        ensure_onboarding_complete!
        token = create_oauth_access_token
        success(oauth_access_token: token)
      end

      private

      def create_oauth_access_token
        OauthAccessToken.create!(
          application_id: ai_settings.duo_workflow_oauth_application_id,
          expires_in: TOKEN_EXPIRES_IN,
          resource_owner_id: @service_account.id,
          organization: @organization,
          scopes: @scopes
        )
      end

      def ensure_onboarding_complete!
        if @service_account.nil? || ai_settings.duo_workflow_oauth_application.nil?
          raise IncompleteOnboardingError,
            'Duo Agent Platform onboarding is incomplete. Please complete onboarding to proceed further.'
        elsif !@service_account.composite_identity_enforced?
          raise CompositeIdentityEnforcedError,
            'The Duo Agent Platform service account must have composite identity enabled.'
        end
      end

      def dynamic_user_scope
        ["user:#{@current_user.id}"]
      end

      def ai_settings
        Ai::Setting.instance
      end
      strong_memoize_attr :ai_settings
    end
  end
end
