# frozen_string_literal: true

module Ai
  class Setting < ApplicationRecord
    self.table_name = "ai_settings"

    validates :ai_gateway_url, length: { maximum: 2048 }, allow_nil: true
    validate :validate_ai_gateway_url
    validate :validates_singleton

    def self.instance
      first || create!(defaults)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      first
    end

    def self.defaults
      { ai_gateway_url: ENV['AI_GATEWAY_URL'] }
    end

    private

    def validates_singleton
      return unless self.class.count > 0 && self != self.class.first

      errors.add(:base, "There can only be one Settings record")
    end

    def validate_ai_gateway_url
      return if ai_gateway_url.blank?

      begin
        Gitlab::HTTP_V2::UrlBlocker.validate!(
          ai_gateway_url,
          schemes: %w[http https],
          enforce_sanitization: true,
          deny_all_requests_except_allowed: Gitlab::CurrentSettings.deny_all_requests_except_allowed?,
          outbound_local_requests_allowlist: Gitlab::CurrentSettings.outbound_local_requests_whitelist # rubocop:disable Naming/InclusiveLanguage -- existing setting
        )
      rescue Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError => e
        errors.add(:ai_gateway_url, "is not allowed: #{e.message}")
      end
    end
  end
end
