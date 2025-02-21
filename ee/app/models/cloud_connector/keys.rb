# frozen_string_literal: true

module CloudConnector
  class Keys < ApplicationRecord
    self.table_name = 'cloud_connector_keys'

    encrypts :secret_key, key_provider: ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
    validates :secret_key, rsa_key: true, allow_nil: true

    scope :valid, -> { where.not(secret_key: nil) }

    class << self
      def all_as_pem
        valid.map(&:secret_key)
      end
    end
  end
end
