# frozen_string_literal: true

module Ai
  class SelfHostedModel < ApplicationRecord
    self.table_name = "ai_self_hosted_models"

    validates :model, presence: true
    validates :endpoint, presence: true, addressable_url: true
    validates :name, presence: true, uniqueness: true

    has_many :feature_settings

    attr_encrypted :api_token,
      mode: :per_attribute_iv,
      key: Settings.attr_encrypted_db_key_base_32,
      algorithm: 'aes-256-gcm',
      encode: true

    enum model: {
      mistral: 0,
      mixtral: 1,
      codegemma: 2,
      codestral: 3,
      codellama: 4,
      codellama_13b_code: 5,
      deepseekcoder: 6,
      mixtral_8x22b: 7,
      codegemma_2b: 8,
      codegemma_7b: 9,
      mistral_text: 10,
      mixtral_text: 11,
      mixtral_8x22b_text: 12,
      llama3: 13,
      llama3_text: 14,
      llama3_70b: 15,
      llama3_70b_text: 16
    }

    # For now, only OpenAI API format is supported, this method will be potentially
    # converted into a configurable database column
    def provider
      :openai
    end
  end
end
