# frozen_string_literal: true

module SecretsManagement
  class TestJwt < SecretsManagerJwt
    # Defaults are nil so these claims are omitted unless explicitly provided.
    def initialize(project_id: nil, aud: nil, user_id: nil, **_)
      super()
      @test_project_id = project_id
      @test_aud        = aud
      @test_user_id    = user_id
    end

    def project_claims
      {
        user_id: @test_user_id || '0',
        project_id: @test_project_id,
        user_login: 'test-system',
        aud: @test_aud,
        namespace_id: '0'
      }.compact
    end
  end
end
