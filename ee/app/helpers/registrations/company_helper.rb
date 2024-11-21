# frozen_string_literal: true

module Registrations
  module CompanyHelper
    def create_company_form_data(onboarding_status_presenter)
      submit_path = users_sign_up_company_path(
        ::Onboarding::StatusPresenter
          .glm_tracking_attributes(params).merge(::Onboarding::StatusPresenter.passed_through_params(params))
      )

      {
        submit_path: submit_path,
        first_name: current_user.first_name,
        last_name: current_user.last_name,
        form_type: onboarding_status_presenter.company_form_type,
        track_action_for_errors: onboarding_status_presenter.tracking_label
      }
    end
  end
end
