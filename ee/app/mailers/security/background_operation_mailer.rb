# frozen_string_literal: true

module Security
  class BackgroundOperationMailer < ApplicationMailer
    helper EmailsHelper

    layout 'mailer'

    def failure_notification(user:, operation:, failed_items:)
      @user = user
      @operation = operation.with_indifferent_access
      @failed_items = failed_items

      @humanized_operation_type = BackgroundOperationTracking.humanized_operation_type(@operation[:operation_type])

      mail(
        to: user.email,
        subject: format(_('Bulk operation failed: %{operation_type}'), operation_type: @humanized_operation_type)
      )
    end
  end
end
