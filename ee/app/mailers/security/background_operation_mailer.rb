# frozen_string_literal: true

module Security
  class BackgroundOperationMailer < ApplicationMailer
    helper EmailsHelper

    layout 'mailer'

    # Regex to match "Project 'Name' (full/path)" pattern in error messages
    PROJECT_REFERENCE_PATTERN = /Project\s+'(?<name>[^']+)'\s+\((?<full_path>[^)]+)\)/

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

    # Converts project references in error messages to clickable links
    # Input: "Project 'Security Reports' (toolbox/security-reports) has reached the maximum limit"
    # Output: "<a href='https://gitlab.com/toolbox/security-reports'>Security Reports</a> has reached the maximum limit"
    def linkify_project_references(message)
      message.gsub(PROJECT_REFERENCE_PATTERN) do
        match = Regexp.last_match
        # Escape the project name to prevent XSS
        project_name = ERB::Util.html_escape(match[:name])
        project_path = match[:full_path]
        project_url = Gitlab::Routing.url_helpers.root_url + project_path

        ActionController::Base.helpers.link_to(project_name, project_url)
      end.html_safe # rubocop:disable Rails/OutputSafety -- Project names are escaped, paths are from database
    end
    helper_method :linkify_project_references
  end
end
