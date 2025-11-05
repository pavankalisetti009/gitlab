# frozen_string_literal: true

module SecretsManagement
  class SecretsManagerJwt < Gitlab::Ci::JwtBase
    DEFAULT_TTL = 30.seconds
    SYSTEM_UID = 'gitlab_secrets_manager'

    attr_reader :current_user, :project, :old_aud

    def initialize(current_user: nil, project: nil, old_aud: nil)
      super()
      @current_user = current_user
      @project = project
      @old_aud = old_aud
    end

    def payload
      now = Time.now.to_i

      payload = {
        iss: Gitlab.config.gitlab.url,
        iat: now,
        nbf: now,
        exp: now + DEFAULT_TTL.to_i,
        jti: SecureRandom.uuid,
        aud: aud,
        sub: SYSTEM_UID,
        secrets_manager_scope: 'privileged',
        correlation_id: Labkit::Correlation::CorrelationId.current_id
      }

      # we include the user and project claims to support detailed context in the audits for every request to OpenBao to
      # track every action to a specific user and project.
      payload = payload.merge(user_project_claims) if project

      # for some actions like recovery key generation, we do not have a user or project and these show a SYSTEM_UID
      # user_id and a nil project_id
      payload[:user_id] ||= SYSTEM_UID
      payload[:project_id] ||= SYSTEM_UID

      payload
    end

    def user_project_claims
      ::JSONWebToken::UserProjectTokenClaims
        .new(project: project, user: current_user)
        .generate
    end

    private

    def aud
      if old_aud.nil?
        SecretsManagement::ProjectSecretsManager.server_url
      else
        old_aud
      end
    end
  end
end
