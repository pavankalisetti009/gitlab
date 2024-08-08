# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ComplianceCheck < ApplicationRecord
      self.table_name = 'compliance_checks'

      enum check_name: ::Enums::Projects::ComplianceStandards::Adherence.check_name

      belongs_to :compliance_requirement,
        class_name: 'ComplianceManagement::ComplianceFramework::ComplianceRequirement', foreign_key: :requirement_id,
        inverse_of: :compliance_checks, optional: false

      validates_presence_of :compliance_requirement, :namespace_id, :check_name
      validates :check_name, uniqueness: { scope: :requirement_id }
    end
  end
end
