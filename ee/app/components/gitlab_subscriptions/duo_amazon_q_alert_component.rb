# frozen_string_literal: true

module GitlabSubscriptions
  class DuoAmazonQAlertComponent < ViewComponent::Base
    include Gitlab::Utils::StrongMemoize

    CALLOUT_FEATURE_NAME = 'duo_amazon_q_alert'

    def initialize(user:)
      @user = user
    end

    private

    attr_reader :user

    def render?
      self_managed_instance? && add_on_purchase.present? && !user_dismissed_alert?
    end

    def self_managed_instance?
      !Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
    end

    def add_on_purchase
      GitlabSubscriptions::DuoAmazonQ.any_add_on_purchase
    end
    strong_memoize_attr :add_on_purchase

    def user_dismissed_alert?
      user.dismissed_callout?(feature_name: CALLOUT_FEATURE_NAME)
    end

    def variant
      case days_to_expiration
      when 16..Float::INFINITY
        :info
      when 2..15
        :warning
      else
        :danger
      end
    end

    def message
      if add_on_purchase.active?
        formatted_date = l(add_on_purchase.expires_on, format: :long)
        Kernel.format(
          s_('AmazonQ|GitLab Duo with Amazon Q - Subscription ends on %{formatted_date}'),
          formatted_date: formatted_date
        )
      else
        s_('AmazonQ|Your GitLab Duo with Amazon Q subscription has ended')
      end
    end

    def alert_options
      {
        class: 'js-persistent-callout gl-mb-5',
        data: {
          feature_id: CALLOUT_FEATURE_NAME,
          dismiss_endpoint: Rails.application.routes.url_helpers.callouts_path,
          testid: 'duo-amazon-q-alert'
        }
      }
    end

    def days_to_expiration
      (add_on_purchase.expires_on.to_date - Date.current).to_i
    end
  end
end
