# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class PolicyViolationComment
      include Rails.application.routes.url_helpers
      include Gitlab::Utils::StrongMemoize

      MESSAGE_HEADER = '<!-- policy_violation_comment -->'
      VIOLATED_REPORTS_HEADER_PATTERN = /<!-- violated_reports: ([a-z_,]+)/
      OPTIONAL_APPROVALS_HEADER_PATTERN = /<!-- optional_approvals: ([a-z_,]+)/
      REPORT_TYPES = {
        license_scanning: 'license_scanning',
        scan_finding: 'scan_finding',
        any_merge_request: 'any_merge_request'
      }.freeze
      MESSAGE_REQUIRES_APPROVAL = <<~MARKDOWN
Security and compliance scanners enforced by your organization have completed and identified that approvals
are required due to one or more policy violations.
Review the policy's rules in the MR widget and assign reviewers to proceed.

Several factors can lead to a violation or required approval in your merge request:

- If merge request approval policies enforced on your project include a scanner in the conditions, the scanner must be properly configured to run in both the source and target branch, the required jobs must complete, and a job artifact containing the scan results must be produced (even if empty).
- If any violation of a merge request approval policy's rules are found, approval is required.
- Approvals are assumed required until all pipelines associated with the merge base commit in the target branch, and all pipelines associated with the latest commit in the source branch, are complete and it's confirmed that no policy violations have occurred.
      MARKDOWN

      MESSAGE_REQUIRES_NO_APPROVAL = <<~TEXT.squish
        Security and compliance scanners enforced by your organization have completed and identified one or more
        policy violations.
        Consider including optional reviewers based on the policy rules in the MR widget.
      TEXT

      attr_reader :reports, :optional_approval_reports, :existing_comment, :merge_request

      def initialize(existing_comment, merge_request)
        @existing_comment = existing_comment
        @reports = Set.new
        @optional_approval_reports = Set.new
        @merge_request = merge_request

        return unless existing_comment

        parse_reports
      end

      def add_report_type(report_type, requires_approval)
        add_optional_approval_report(report_type) unless requires_approval
        @reports = (reports + [report_type]) & REPORT_TYPES.values
      end

      def add_optional_approval_report(report_type)
        @optional_approval_reports = (optional_approval_reports + [report_type]) & REPORT_TYPES.values
      end

      def remove_report_type(report_type)
        @optional_approval_reports -= [report_type]
        @reports -= [report_type]
      end

      def clear_report_types
        @optional_approval_reports.clear
        @reports.clear
      end

      def body
        return if existing_comment.nil? && reports.empty?

        [MESSAGE_HEADER, body_message].join("\n")
      end
      strong_memoize_attr :body

      private

      delegate :project, to: :merge_request

      def parse_reports
        parse_report_list(VIOLATED_REPORTS_HEADER_PATTERN) { |report_type| add_report_type(report_type, true) }
        parse_report_list(OPTIONAL_APPROVALS_HEADER_PATTERN) { |report_type| add_optional_approval_report(report_type) }
      end

      def parse_report_list(pattern, &block)
        match = existing_comment.note.match(pattern)
        match[1].split(',').each(&block) if match
      end

      def fixed_note_body
        'Security policy violations have been resolved.'
      end

      def links_approvals_required
        <<~MARKDOWN

          [View policies enforced on your project](#{project_security_policies_url(project)}).<br>
          [View further troubleshooting guidance](#{help_page_url('user/application_security/policies/index', anchor: 'troubleshooting-common-issues-configuring-security-policies')}).
        MARKDOWN
      end

      def reports_header
        optional_approvals_sorted_list = optional_approval_reports.sort.join(',')

        <<~MARKDOWN
        <!-- violated_reports: #{reports.sort.join(',')} -->
        #{"<!-- optional_approvals: #{optional_approvals_sorted_list} -->" if optional_approval_reports.any?}
        MARKDOWN
      end

      def body_message
        return fixed_note_body if reports.empty?

        message, links = if only_optional_approvals?
                           [MESSAGE_REQUIRES_NO_APPROVAL, '']
                         else
                           [MESSAGE_REQUIRES_APPROVAL, links_approvals_required]
                         end

        <<~MARKDOWN
          #{reports_header}
          :warning: **Policy violation(s) detected**

          #{message}#{links}

          #{format('Learn more about [Security and compliance policies](%{url}).',
            url: help_page_url('user/application_security/policies/index'))}
        MARKDOWN
      end

      def only_optional_approvals?
        reports == optional_approval_reports
      end
    end
  end
end
