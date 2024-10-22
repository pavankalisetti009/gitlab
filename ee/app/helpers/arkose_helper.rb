# frozen_string_literal: true

module ArkoseHelper
  def arkose_data_exchange_payload(use_case)
    show_challenge =
      if use_case == Arkose::DataExchangePayload::USE_CASE_SIGN_UP
        PhoneVerification::Users::RateLimitService.daily_transaction_hard_limit_exceeded?
      else
        use_case == Arkose::DataExchangePayload::USE_CASE_IDENTITY_VERIFICATION
      end

    Arkose::DataExchangePayload.new(
      request,
      use_case: use_case,
      require_challenge: show_challenge
    ).build
  end
end
