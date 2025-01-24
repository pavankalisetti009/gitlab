# frozen_string_literal: true

module Namespaces
  module Storage
    class RepositoryLimitMailer < ApplicationMailer
      include EmailsHelper

      helper EmailsHelper

      layout 'mailer'

      def notify_out_of_storage(project_name:, recipients:)
        @support_url = 'https://support.gitlab.com'
        @project_name = project_name

        subject = safe_format(_('Action required: %{project_name} is read-only'), { project_name: @project_name })

        mail_with_locale(
          bcc: recipients,
          subject: subject
        )
      end
    end
  end
end
