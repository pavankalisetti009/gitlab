# frozen_string_literal: true

module Gitlab
  module Checks
    module SecretPushProtection
      class PostPushWarning < ::Gitlab::Checks::PostPushMessage
        MESSAGE_KEY_PREFIX = 'secret_push_protection:warning'

        def self.message_key(user, repository)
          [
            MESSAGE_KEY_PREFIX,
            user&.id,
            repository&.project&.id
          ].compact.join(':')
        end

        def message
          'Secret push protection encountered an internal error and could not ' \
            'scan this push. The push has been accepted.'
        end
      end
    end
  end
end
