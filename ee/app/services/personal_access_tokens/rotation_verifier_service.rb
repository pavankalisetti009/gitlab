# frozen_string_literal: true

module PersonalAccessTokens
  class RotationVerifierService
    def initialize(user)
      @user = user
    end

    def clear_cache
      Rails.cache.delete(expired_cache_key)
      Rails.cache.delete(expiring_cache_key)
    end

    private

    attr_reader :user

    NUMBER_OF_MINUTES = 60

    def expired_cache_key
      ['users', user.id, 'token_expired_rotation']
    end

    def expiring_cache_key
      ['users', user.id, 'token_expiring_rotation']
    end

    def tokens_without_impersonation
      @tokens_without_impersonation ||= user
        .personal_access_tokens
        .without_impersonation
    end

    # Expire the cache at the end of day
    # Calculates the number of minutes remaining from now until end of day
    def expires_in
      (Time.current.at_end_of_day - Time.current) / NUMBER_OF_MINUTES
    end
  end
end
