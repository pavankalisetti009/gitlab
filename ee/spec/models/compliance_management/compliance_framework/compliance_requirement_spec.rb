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
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(255) }

    describe '#requirements_count_per_framework' do
      let_it_be(:compliance_framework_1) { create(:compliance_framework, :sox, namespace: group) }

      subject(:new_compliance_requirement) { build(:compliance_requirement, framework: compliance_framework_1) }

      context 'when requirements count is one less than max count' do
        before do
          49.times do |i|
            create(:compliance_requirement, framework: compliance_framework_1, name: "Test#{i}")
          end
        end

        it 'creates requirement with no error' do
          expect(new_compliance_requirement.valid?).to eq(true)
          expect(new_compliance_requirement.errors).to be_empty
        end
      end

      context 'when requirements count is equal to max count' do
        before do
          50.times do |i|
            create(:compliance_requirement, framework: compliance_framework_1, name: "Test#{i}")
          end
        end

        it 'returns error' do
          expect(new_compliance_requirement.valid?).to eq(false)
          expect(new_compliance_requirement.errors.full_messages)
            .to contain_exactly("Framework cannot have more than 50 requirements")
        end
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:framework).optional(false) }
    it { is_expected.to belong_to(:namespace).optional(false) }
    it { is_expected.to have_many(:security_policy_requirements) }
    it { is_expected.to have_many(:compliance_framework_security_policies).through(:security_policy_requirements) }
    it { is_expected.to have_many(:compliance_requirements_controls) }
    it { is_expected.to have_many(:project_control_compliance_statuses) }
  end
end
