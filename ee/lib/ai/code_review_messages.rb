# frozen_string_literal: true

module Ai
  module CodeReviewMessages
    module_function

    def automatic_error
      s_(
        "DuoCodeReview|GitLab Duo Code Review was not automatically added because " \
          "your account requires GitLab Duo Enterprise. Contact your administrator to upgrade your account."
      )
    end

    def manual_error
      s_(
        "DuoCodeReview|You don't have access to GitLab Duo Code Review. " \
          "This feature requires GitLab Duo Enterprise. Contact your administrator to upgrade your account."
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
  end
end
