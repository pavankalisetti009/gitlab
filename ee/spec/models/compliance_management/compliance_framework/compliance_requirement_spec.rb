# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirement,
  type: :model, feature_category: :compliance_management do
  describe 'validations' do
    let_it_be(:group) { create(:group) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: group) }
    let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework) }

    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:framework_id) }
    it { is_expected.to validate_presence_of(:namespace_id) }
    it { is_expected.to validate_presence_of(:framework) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:description) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:framework).optional(false) }
    it { is_expected.to have_many(:security_policy_requirements) }
    it { is_expected.to have_many(:compliance_framework_security_policies).through(:security_policy_requirements) }
  end
end
