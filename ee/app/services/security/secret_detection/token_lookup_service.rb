# frozen_string_literal: true

module Security
  module SecretDetection
    class TokenLookupService
      # Maps token type IDs to their corresponding GitLab model classes
      TOKEN_TYPE_CONFIG = {
        'gitlab_personal_access_token' => {
          model: PersonalAccessToken,
          lookup_method: :token_digest_lookup
        }
      }.freeze

      # Find tokens in database based on token type and values
      # @param token_type [String] The token type ID
      # @param token_values [Array<String>] Array of token digests to look up
      # @return [ActiveRecord::Relation] Collection of found tokens (may be empty if none found)
      def find(token_type, token_values)
        config = TOKEN_TYPE_CONFIG[token_type]
        return unless config

        model_class = config[:model]
        lookup_method = config[:lookup_method]

        case lookup_method
        when :token_digest_lookup
          token_digest_lookup(model_class, token_values)
        end
      end

      private

      # Lookup tokens using their digests (for tokens stored with token_digest)
      # @param model_class [Class] The token model class
      # @param token_values [Array<String>] Array of raw token values to look up
      # @return [ActiveRecord::Relation] Collection of found tokens
      def token_digest_lookup(model_class, token_values)
        token_digests = token_values.map { |token_value| Gitlab::CryptoHelper.sha256(token_value) }
        model_class.with_token_digests(token_digests)
      end
    end
  end
end
