# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateOauthAccessTokenService
      include ::Services::ReturnServiceResponses

      def initialize(current_user:)
        @current_user = current_user
      end

      def execute
        return error('Duo workflow is not enabled for user', :forbidden) unless Feature.enabled?(:duo_workflow,
          current_user)

        ensure_oauth_application!
        token = find_or_create_oauth_access_token
        success(oauth_access_token: token)
      end

      private

      attr_reader :current_user

      def find_or_create_oauth_access_token
        existing_token = Doorkeeper::AccessToken.matching_token_for(
          oauth_application,
          current_user.id,
          oauth_application.scopes,
          include_expired: false
        )

        return existing_token if existing_token

        Doorkeeper::AccessToken.create!(
          application_id: oauth_application.id,
          expires_in: 2.hours,
          resource_owner_id: current_user.id,
          token: Doorkeeper::OAuth::Helpers::UniqueToken.generate,
          scopes: oauth_application.scopes.to_s
        )
      end

      def ensure_oauth_application!
        return if oauth_application

        should_expire_cache = false

        application_settings.with_lock do
          # note: `with_lock` busts application_settings cache and will trigger another query.
          # We need to double check here so that requests previously waiting on the lock can
          # now just skip.
          next if oauth_application

          application = Doorkeeper::Application.new(
            name: 'GitLab Duo Workflow',
            redirect_uri: oauth_callback_url,
            scopes: ::Gitlab::Auth::AI_WORKFLOW_SCOPES,
            trusted: true,
            confidential: false
          )
          application.save!
          application_settings.update!(duo_workflow: { duo_workflow_oauth_application_id: application.id })
          should_expire_cache = true
        end

        # note: This needs to happen outside the transaction, but only if we actually changed something
        ::Gitlab::CurrentSettings.expire_current_application_settings if should_expire_cache
      end

      def application_settings
        ::Gitlab::CurrentSettings.current_application_settings
      end

      def oauth_application
        oauth_application_id = application_settings.duo_workflow_oauth_application_id
        return unless oauth_application_id

        Doorkeeper::Application.find(oauth_application_id)
      end

      def oauth_callback_url
        # This value is unused but cannot be nil
        Gitlab::Routing.url_helpers.root_url
      end
    end
  end
end
