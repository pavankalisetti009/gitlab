# frozen_string_literal: true

module Sbom
  class ExportMailer < ApplicationMailer
    helper ::EmailsHelper
    helper ::DependenciesHelper

    layout 'mailer'

    def completion_email(export, group)
      @export = export

      mail_with_locale(
        to: export.author.notification_email_for(group),
        subject: _("Dependency list export")
      )
    end
  end
end
