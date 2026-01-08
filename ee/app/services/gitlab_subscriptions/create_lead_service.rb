# frozen_string_literal: true

module GitlabSubscriptions
  class CreateLeadService
    def execute(company_params)
      company_params.merge!(with_add_on: true, add_on_name: 'duo_enterprise')

      response = if Feature.enabled?(:new_trial_lead_endpoint, User.find_by_id(company_params[:uid]))
                   client.generate_trial_lead(company_params)
                 else
                   client.generate_trial(company_params)
                 end

      if response[:success]
        ServiceResponse.success
      else
        error_message = response.dig(:data, :errors) || 'Submission failed'
        ServiceResponse.error(message: error_message, reason: :submission_failed)
      end
    end

    private

    def client
      Gitlab::SubscriptionPortal::Client
    end
  end
end
