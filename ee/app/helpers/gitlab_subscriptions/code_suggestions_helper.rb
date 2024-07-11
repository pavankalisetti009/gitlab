# frozen_string_literal: true

module GitlabSubscriptions
  module CodeSuggestionsHelper
    include GitlabSubscriptions::SubscriptionHelper

    def duo_pro_bulk_user_assignment_available?(namespace = nil)
      if gitlab_com_subscription?
        Feature.enabled?(:gitlab_com_duo_pro_bulk_user_assignment, namespace)
      else
        Feature.enabled?(:sm_duo_pro_bulk_user_assignment)
      end
    end

    def add_duo_pro_seats_url(subscription_name)
      ::Gitlab::Routing.url_helpers.subscription_portal_add_sm_duo_pro_seats_url(subscription_name)
    end
  end
end
