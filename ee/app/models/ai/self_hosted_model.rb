# frozen_string_literal: true

module Ai
  class SelfHostedModel < ApplicationRecord
    self.table_name = "ai_self_hosted_models"

    validates :model, presence: true
    validates :endpoint, presence: true, addressable_url: true
    validates :name, presence: true, uniqueness: true
    validates :identifier, length: { maximum: 255 }, allow_nil: true

    has_many :feature_settings, foreign_key: :ai_self_hosted_model_id, inverse_of: :self_hosted_model

    attr_encrypted :api_token,
      mode: :per_attribute_iv,
      key: Settings.attr_encrypted_db_key_base_32,
      algorithm: 'aes-256-gcm',
      encode: true

    enum model: {
      mistral: 0,
      llama3: 1,
      codegemma: 2,
      codestral: 3,
      codellama: 4,
      deepseekcoder: 5,
      claude_3: 6,
      gpt: 7,
      mixtral: 8
    }

    # For now, only OpenAI API format is supported, this method will be potentially
    # converted into a configurable database column
    def provider
      :openai
    end

    def identifier
      self[:identifier] || ''
    end
  end
end
