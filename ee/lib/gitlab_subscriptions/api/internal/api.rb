# frozen_string_literal: true

module GitlabSubscriptions
  module API
    module Internal
      class API < ::API::Base
        helpers GitlabSubscriptions::API::Internal::Helpers

        before do
          if jwt_request?
            authenticate_from_jwt!
          else
            authenticated_as_admin!
          end
        end

        mount ::GitlabSubscriptions::API::Internal::Members
        mount ::GitlabSubscriptions::API::Internal::Namespaces
        mount ::GitlabSubscriptions::API::Internal::Subscriptions
        mount ::GitlabSubscriptions::API::Internal::UpcomingReconciliations
        mount ::GitlabSubscriptions::API::Internal::Users
      end
    end
  end
end
