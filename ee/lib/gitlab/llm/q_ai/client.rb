# frozen_string_literal: true

module Gitlab
  module Llm
    module QAi
      class Client
        def initialize(user)
          @user = user
        end

        def perform_create_auth_application(oauth_app, secret, role_arn)
          payload = {
            client_id: oauth_app.uid.to_s,
            client_secret: secret,
            redirect_url: oauth_app.redirect_uri,
            instance_url: Gitlab.config.gitlab.url,
            role_arn: role_arn
          }

          Gitlab::HTTP.post(
            "#{url}/v1/amazon_q/oauth/application",
            body: payload.to_json,
            headers: request_headers
          )
        end

        private

        attr_reader :user

        def url
          Gitlab::AiGateway.url
        end

        def service_name
          :amazon_q_integration
        end

        def service
          ::CloudConnector::AvailableServices.find_by_name(service_name)
        end

        def request_headers
          {
            "Accept" => "application/json",
            # Note: In this case, the service is the same as the unit primitive name
            'X-Gitlab-Unit-Primitive' => service_name.to_s
          }.merge(Gitlab::AiGateway.headers(user: user, service: service))
        end
      end
    end
  end
end
