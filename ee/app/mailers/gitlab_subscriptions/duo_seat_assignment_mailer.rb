# frozen_string_literal: true

module GitlabSubscriptions
  class DuoSeatAssignmentMailer < ApplicationMailer
    helper SafeFormatHelper
    helper EmailsHelper

    def duo_pro_email(user)
      email = user.notification_email_or_default
      mail_with_locale(to: email, subject: s_('CodeSuggestions|Welcome to GitLab Duo Pro!'))
    end
  end
end
