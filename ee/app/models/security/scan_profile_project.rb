# frozen_string_literal: true

module Security
  class ScanProfileProject < ::SecApplicationRecord
    self.table_name = 'security_scan_profiles_projects'

    belongs_to :project, optional: false
    belongs_to :scan_profile, class_name: 'Security::ScanProfile', foreign_key: :security_scan_profile_id,
      inverse_of: :scan_profile_projects, optional: false

    validates :project_id, uniqueness: { scope: :security_scan_profile_id }
  end
end
