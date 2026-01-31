# frozen_string_literal: true

module Security
  module Ascp
    class SecurityGuideline < ::SecApplicationRecord
      self.table_name = 'ascp_security_guidelines'

      belongs_to :project
      belongs_to :scan, class_name: 'Security::Ascp::Scan'
      belongs_to :security_context, class_name: 'Security::Ascp::SecurityContext', inverse_of: :guidelines

      validates :project, :scan, :security_context, :name, :operation, presence: true

      # Inline enum - DO NOT use Enums::Ascp module
      enum :severity_if_violated, { low: 0, medium: 1, high: 2, critical: 3 }

      scope :at_scan, ->(scan_id) { where(scan_id: scan_id) }
    end
  end
end
