# frozen_string_literal: true

module Gitlab
  module Database
    module Encryption
      class KeyProviderService
        KeyProviderBuilder = Struct.new(:builder_class, :secrets, keyword_init: true) do
          def build
            builder_class.new(secrets.call)
          end

          def builder_class
            @builder_class ||= self[:builder_class] || NonDerivedKeyProvider
          end
        end

        KEY_PROVIDER_WRAPPERS = {
          db_key_base: KeyProviderBuilder.new(
            secrets: -> { Settings.db_key_base_keys }
          ),
          db_key_base_32: KeyProviderBuilder.new(
            secrets: -> { Settings.db_key_base_keys_32_bytes }
          ),
          db_key_base_truncated: KeyProviderBuilder.new(
            secrets: -> { Settings.db_key_base_keys_truncated }
          ),
          active_record_encryption_primary_key: KeyProviderBuilder.new(
            builder_class: ActiveRecord::Encryption::DerivedSecretKeyProvider,
            secrets: -> { ActiveRecord::Encryption.config.primary_key }
          ),
          active_record_encryption_deterministic_key: KeyProviderBuilder.new(
            builder_class: ActiveRecord::Encryption::DerivedSecretKeyProvider,
            secrets: -> { ActiveRecord::Encryption.config.deterministic_key }
          )
        }.freeze

        def initialize(key_type = nil)
          @key_type = key_type&.to_sym
        end

        delegate :encryption_key, to: :key_provider

        def key_provider
          @key_provider ||= key_provider_builder.build
        end

        def key_provider_builder
          @key_provider_builder ||= KEY_PROVIDER_WRAPPERS.fetch(@key_type)
        end

        def decryption_keys
          key_provider.decryption_keys(ActiveRecord::Encryption::Message.new)
        end
      end
    end
  end
end
