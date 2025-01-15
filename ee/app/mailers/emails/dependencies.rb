# frozen_string_literal: true

module Emails
  module Dependencies
    def dependency_export_completion_email(export, group)
      @export = export

      email_with_layout(
        to: export.author.notification_email_for(group),
        subject: subject(s_("Dependencies|Dependency list export"))
      )
    end
  end
end
