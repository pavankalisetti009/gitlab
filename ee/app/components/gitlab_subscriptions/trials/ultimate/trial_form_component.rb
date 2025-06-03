# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module Ultimate
      class TrialFormComponent < ViewComponent::Base
        include TrialFormDisplayUtilities

        def initialize(**kwargs)
          @user = kwargs[:user]
          @params = kwargs[:params]
        end

        private

        attr_reader :user, :params

        delegate :page_title, to: :helpers

        def form_data
          ::Gitlab::Json.generate(
            {
              userData: user_data,
              submitPath: submit_path,
              gtmSubmitEventLabel: 'saasTrialSubmit'
            }
          )
        end

        def user_data
          {
            firstName: user.first_name,
            lastName: user.last_name,
            showNameFields: user.last_name.blank?,
            emailDomain: user.email_domain,
            companyName: user.organization,
            phoneNumber: nil,
            country: '',
            state: ''
          }
        end

        def submit_path
          trials_path(
            step: GitlabSubscriptions::Trials::CreateService::LEAD,
            **params.slice(*::Onboarding::StatusPresenter::GLM_PARAMS, :namespace_id)
          )
        end
      end
    end
  end
end
