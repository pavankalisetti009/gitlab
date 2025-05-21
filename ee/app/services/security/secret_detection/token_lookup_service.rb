# frozen_string_literal: true

module Security
  module SecretDetection
    class TokenLookupService
      # Maps token type IDs to their corresponding GitLab model classes
      TOKEN_TYPE_CONFIG = {
        'gitlab_personal_access_token' => {
          model: PersonalAccessToken,
          lookup_method: :token_digest_lookup
        },
        'gitlab_deploy_token' => {
          model: DeployToken,
          lookup_method: :deploy_token_lookup
        }
      }.freeze

      # Find tokens in database based on token type and values
      # @param token_type [String] The token type ID
      # @param token_values [Array<String>] Array of raw token values to look up
      # @return [Hash] Hash mapping raw token values to their corresponding token objects
      def find(token_type, token_values)
        config = TOKEN_TYPE_CONFIG[token_type]
        return unless config

        model_class = config[:model]
        lookup_method = config[:lookup_method]

        case lookup_method
        when :token_digest_lookup
          token_digest_lookup(model_class, token_values)
        when :deploy_token_lookup
          token_lookup(model_class, token_values)
        end
      end

      private

      # Lookup tokens using their digests (for tokens stored with token_digest)
      # @param model_class [Class] The token model class
      # @param token_values [Array<String>] Array of raw token values to look up
      # @return [Hash] Hash mapping raw token values to their corresponding token objects
      def token_digest_lookup(model_class, token_values)
        token_digest_to_raw_token = token_values.each_with_object({}) do |raw_token_value, result|
          result[Gitlab::CryptoHelper.sha256(raw_token_value)] = raw_token_value
          result
        end
        results = model_class.with_token_digests(token_digest_to_raw_token.keys)

        results.each_with_object({}) do |found_token, result|
          raw_token = token_digest_to_raw_token[found_token.token_digest]
          result[raw_token] = found_token
        end
      end

      # Lookup tokens using their encrypted values
      # @param model_class [Class] The token model class
      # @param token_values [Array<String>] Array of raw token values
      # @return [Hash] Hash mapping raw token values to their corresponding token objects
      def token_lookup(model_class, token_values)
        encrypted_to_raw_token = token_values.each_with_object({}) do |raw_token_value, result|
          encrypted = Authn::TokenField::EncryptionHelper.encrypt_token(raw_token_value)
          result[encrypted] = raw_token_value
        end

        results = model_class.with_encrypted_tokens(encrypted_to_raw_token.keys)

        results.each_with_object({}) do |found_token, result|
          raw_token = encrypted_to_raw_token[found_token.token_encrypted]
          result[raw_token] = found_token
        end
      end
    end
  end
end
