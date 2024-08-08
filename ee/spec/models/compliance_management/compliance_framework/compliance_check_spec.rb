# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceCheck,
  type: :model, feature_category: :compliance_management do
  describe 'validations' do
    let_it_be(:group) { create(:group) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: group) }
    let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework) }

    let_it_be(:check_1) do
      create(:compliance_check, compliance_requirement: requirement, check_name: :at_least_two_approvals)
    end

    it { is_expected.to validate_uniqueness_of(:check_name).scoped_to(:requirement_id).ignoring_case_sensitivity }
    it { is_expected.to validate_presence_of(:namespace_id) }
    it { is_expected.to validate_presence_of(:compliance_requirement) }
    it { is_expected.to validate_presence_of(:check_name) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:compliance_requirement).optional(false) }
  end
end
