# frozen_string_literal: true

module SecretsManagement
  class TestJwt < SecretsManagerJwt
    # Defaults are nil so these claims are omitted unless explicitly provided.
    def initialize(project_id: nil, aud: nil, user_id: nil, user_name: nil, scope: :global, **_)
      super()
      @test_project_id = project_id
      @test_aud        = aud
      @test_user_id    = user_id
      @test_user_name  = user_name
      @scope = scope
    end

    def user_project_claims
      {
        user_id: @test_user_id || '0',
        project_id: @test_project_id,
        user_login: 'test-system',
        aud: @test_aud,
        namespace_id: '0'
      }.compact
    end

    def payload
      claims = super
      claims = claims.merge(user_project_claims) # super may not always call this method
      claims[:sub] = sub
      claims[:secrets_manager_scope] = secrets_manager_scope
      claims
    end

    private

    def secrets_manager_scope
      if @scope == :user
        'user'
      elsif @scope == :global
        'privileged'
      end
    end

    def sub
      if @scope == :user
        @test_user_name ? "user:#{@test_user_name}" : nil
      elsif @scope == :global
        'gitlab_secrets_manager'
      end
    end
  end
end
