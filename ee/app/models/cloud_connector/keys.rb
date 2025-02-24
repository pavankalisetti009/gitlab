# frozen_string_literal: true

module CloudConnector
  class Keys < ApplicationRecord
    self.table_name = 'cloud_connector_keys'

    encrypts :secret_key, key_provider: ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
    validates :secret_key, rsa_key: true, allow_nil: true

    scope :valid, -> { where.not(secret_key: nil) }

    class << self
      def current
        valid.order(created_at: :asc).first
      end

      def current_as_jwk
        current&.secret_key&.then do |key_data|
          ::JWT::JWK.new(OpenSSL::PKey::RSA.new(key_data), kid_generator: ::JWT::JWK::Thumbprint)
        end
      end

      def all_as_pem
        valid.map(&:secret_key)
      end
    end
  end
end
