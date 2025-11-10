# frozen_string_literal: true

module Ai
  module CodeReview
    module_function

    def automatic_error_message
      s_(
        "DuoCodeReview|GitLab Duo Code Review was not automatically added because " \
          "your account requires GitLab Duo Enterprise. Contact your administrator to upgrade your account."
      )
    end

    def manual_error_message
      s_(
        "DuoCodeReview|You don't have access to GitLab Duo Code Review. " \
          "This feature requires GitLab Duo Enterprise. Contact your administrator to upgrade your account."
      )
    end
  end
end
