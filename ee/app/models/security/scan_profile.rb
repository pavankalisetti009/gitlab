# frozen_string_literal: true

module Security
  class ScanProfile < ::SecApplicationRecord
    include StripAttribute

    self.table_name = 'security_scan_profiles'
    strip_attributes! :name, :description

    belongs_to :namespace, optional: false

    enum :scan_type, Enums::Security.scan_profile_types

    validates :scan_type, presence: true
    validates :gitlab_recommended, inclusion: { in: [true, false] }
    validates :name, uniqueness: { scope: [:namespace_id, :scan_type] }, length: { maximum: 255 }, presence: true
    validates :description, length: { maximum: 2047 }, allow_blank: true
    validate :root_namespace_validation

    private

    def root_namespace_validation
      errors.add(:namespace, 'must be a root namespace.') unless namespace&.root?
    end
  end
end
