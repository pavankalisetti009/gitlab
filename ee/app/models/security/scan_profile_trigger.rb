# frozen_string_literal: true

module Security
  class ScanProfileTrigger < ::SecApplicationRecord
    self.table_name = 'security_scan_profile_triggers'

    belongs_to :namespace, optional: false
    belongs_to :scan_profile, class_name: 'Security::ScanProfile', foreign_key: :security_scan_profile_id,
      inverse_of: :scan_profile_triggers, optional: false

    enum :trigger_type, Enums::Security.scan_profile_trigger_types

    validates :trigger_type, presence: true
    validates :security_scan_profile_id, uniqueness: { scope: :trigger_type }
  end
end
