# frozen_string_literal: true

module Security
  module Ascp
    class SecurityContext < ::SecApplicationRecord
      self.table_name = 'ascp_security_contexts'

      belongs_to :project
      belongs_to :scan, class_name: 'Security::Ascp::Scan'
      belongs_to :component, class_name: 'Security::Ascp::Component', inverse_of: :security_context

      has_many :guidelines, class_name: 'Security::Ascp::SecurityGuideline', inverse_of: :security_context

      validates :project, :scan, :component, presence: true
      validates :component_id, uniqueness: { scope: [:project_id, :scan_id] }

      scope :at_scan, ->(scan_id) { where(scan_id: scan_id) }
    end
  end
end
