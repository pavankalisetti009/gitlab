# frozen_string_literal: true

module SecretsManagement
  class SecretsManagerJwt < Gitlab::Ci::JwtBase
    DEFAULT_TTL = 30.seconds

    attr_reader :current_user, :project, :old_aud

    def initialize(current_user: nil, project: nil, old_aud: nil)
      super()
      @current_user = current_user
      @project = project
      @old_aud = old_aud
    end

    def payload
      now = Time.now.to_i

      {
        iss: Gitlab.config.gitlab.url,
        iat: now,
        nbf: now,
        exp: now + DEFAULT_TTL.to_i,
        jti: SecureRandom.uuid,
        aud: aud,
        sub: 'gitlab_secrets_manager',
        secrets_manager_scope: 'privileged',
        correlation_id: Labkit::Correlation::CorrelationId.current_id
      }.merge(project_claims)
    end

    def project_claims
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
