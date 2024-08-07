# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      class AccessProbe < BaseProbe
        def execute(*)
          access_record = CloudConnector::Access.last
          return failure(missing_access_data_text) unless access_record

          is_stale = (Time.current - access_record.updated_at) > CloudConnector::Access::STALE_PERIOD
          return failure(stale_access_data_text) if is_stale

          last_token = CloudConnector::ServiceAccessToken.last
          return failure(missing_access_token_text) unless last_token
          return failure(expired_access_token_text) if last_token.expired?

          success(_("Subscription synchronized successfully."))
        end

        private

        # Keeping this as a separate translation key since we want to eventually link this
        # to subscriptions/self_managed/index.html#manually-synchronize-subscription-data
        def synchronize_subscription_cta
          _('Synchronize your subscription.')
        end

        def missing_access_data_text
          format(_("Subscription has not yet been synchronized. %{cta}"), cta: synchronize_subscription_cta)
        end

        def stale_access_data_text
          format(_("Subscription has not been synchronized recently. %{cta}"), cta: synchronize_subscription_cta)
        end

        def missing_access_token_text
          format(_("Access credentials not found. %{cta}"), cta: synchronize_subscription_cta)
        end

        def expired_access_token_text
          format(_("Access credentials expired. %{cta}"), cta: synchronize_subscription_cta)
        end
      end
    end
  end
end
