# frozen_string_literal: true

module Ai
  module CodeReviewMessages
    module_function

    def automatic_error
      s_(
        "DuoCodeReview|GitLab Duo Code Review was not automatically added. " \
          "Contact your administrator to verify your account has access to this feature."
      )
    end

    def manual_error
      s_(
        "DuoCodeReview|You don't have access to GitLab Duo Code Review. " \
          "Contact your administrator to verify your account has access to this feature."
      )
    end

    def merge_request_not_found_error
      s_(
        "DuoCodeReview|Can't access the merge request. When SAML single sign-on is enabled on a group or its " \
          "parent, Duo Code Reviews can't be requested from the API. Request a review from the GitLab UI instead."
      )
    end

    def progress_note_not_found_error
      s_(
        "DuoCodeReview|Can't create the progress note. This can happen if the Duo Code Review bot does not " \
          "have permission to create notes on the merge request."
      )
    end

    def generic_error
      s_(
        "DuoCodeReview|I have encountered some problems while I was reviewing. Please try again later."
      )
    end

    def nothing_to_review
      s_("DuoCodeReview|:wave: There's nothing for me to review.")
    end

    def nothing_to_comment
      s_("DuoCodeReview|I finished my review and found nothing to comment on. Nice work! :tada:")
    end

    def invalid_review_output
      s_(
        "DuoCodeReview|:warning: Something went wrong while I was processing the review results. " \
          "Please request a new review."
      )
    end

    def could_not_start_workflow_error
      s_(
        "DuoCodeReview|:warning: Something went wrong while requesting a review from GitLab Duo. " \
          "Please request a new review."
      )
    end

    def exception_when_starting_workflow_error
      message_with_error_code(
        s_(
          "DuoCodeReview|:warning: Something went wrong while starting Code Review Flow. " \
            "Please try again later."
        ),
        "DCR5000"
      )
    end

    def foundational_flow_not_enabled_error
      message_with_error_code(
        s_(
          "DuoCodeReview|:warning: Code Review Flow is not enabled. " \
            "Contact your group administrator to enable the foundational flow in the top-level group."
        ),
        "DCR4000"
      )
    end

    def missing_service_account_error
      message_with_error_code(
        s_(
          "DuoCodeReview|:warning: Code Review Flow is enabled " \
            "but the service account needs to be verified. Contact your administrator."
        ),
        "DCR4001"
      )
    end

    def usage_quota_exceeded_error
      message_with_error_code(
        s_(
          "DuoCodeReview|:warning: No GitLab Credits remain for this billing period. " \
            "To continue using Code Review Flow, contact your administrator."
        ),
        "DCR4002"
      )
    end

    def namespace_missing_error(user)
      docs_url = Rails.application.routes.url_helpers.help_page_url(
        'user/profile/preferences.md',
        anchor: 'set-a-default-gitlab-duo-namespace'
      )

      format(
        s_(
          "DuoCodeReview|:warning: %{user_reference}, you need to set a default namespace to " \
            "use Code Review Flow in this project. " \
            "Please set a default GitLab Duo namespace in your [preferences](%{docs_url})."
        ),
        user_reference: user.to_reference,
        docs_url: docs_url
      )
    end

    def timeout_error
      s_(
        "DuoCodeReview|:warning: Something went wrong and the review request was stopped. " \
          "Please request a new review."
      )
    end

    def could_not_generate_summary_error
      s_("DuoCodeReview|:warning: Something went wrong while GitLab Duo was generating a code review summary.")
    end

    def message_with_error_code(message, error_code)
      error_code_url = Rails.application.routes.url_helpers.help_page_url(
        'user/duo_agent_platform/flows/foundational_flows/code_review.md',
        anchor: "error-#{error_code.downcase}"
      )

      error_info = format(
        s_(
          "DuoCodeReview|Error code: [%{error_code}](%{error_code_url})"
        ),
        error_code_url: error_code_url,
        error_code: error_code
      )

      "#{message}\n\n#{error_info}"
    end
  end
end
