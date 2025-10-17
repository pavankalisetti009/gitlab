# frozen_string_literal: true

module SecretsManagement
  class PipelineJwt < Gitlab::Ci::JwtV2
    private

    def predefined_claims
      super.merge(secrets_manager_scope: 'pipeline')
    end
  end
end
