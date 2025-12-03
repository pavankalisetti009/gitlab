# frozen_string_literal: true

module Security
  class ScanProfile < ::SecApplicationRecord
    include StripAttribute

    self.table_name = 'security_scan_profiles'
    strip_attributes! :name, :description

    belongs_to :namespace, optional: false

    enum :scan_type, Enums::Security.scan_profile_types

    has_many :scan_profile_projects, class_name: 'Security::ScanProfileProject',
      foreign_key: :security_scan_profile_id, inverse_of: :scan_profile
    has_many :projects, through: :scan_profile_projects
    has_many :scan_profile_triggers, class_name: 'Security::ScanProfileTrigger',
      foreign_key: :security_scan_profile_id, inverse_of: :scan_profile

    validates :scan_type, presence: true
    validates :gitlab_recommended, inclusion: { in: [true, false] }
    validates :name, uniqueness: { scope: [:namespace_id, :scan_type] }, length: { maximum: 255 }, presence: true
    validates :description, length: { maximum: 2047 }, allow_blank: true
    validate :root_namespace_validation

    scope :by_namespace, ->(namespace) { where(namespace: namespace) }
    scope :by_type, ->(type) { where(scan_type: type) }

    private

    def root_namespace_validation
      errors.add(:namespace, 'must be a root namespace.') unless namespace&.root?
    end
  end
end
