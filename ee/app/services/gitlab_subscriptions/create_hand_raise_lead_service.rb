# frozen_string_literal: true

module GitlabSubscriptions
  class CreateHandRaiseLeadService
    attr_reader :user

    def initialize(user: nil)
      @user = user
    end

    def execute(params)
      response = client.generate_lead(params, user: user)

      if response[:success]
        ServiceResponse.success
      else
        ServiceResponse.error(message: response.dig(:data, :errors))
      end
    end

    private

    def client
      Gitlab::SubscriptionPortal::Client
    end
  end
end
