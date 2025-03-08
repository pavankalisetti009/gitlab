# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus, type: :model,
  feature_category: :compliance_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:compliance_framework) }
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:compliance_requirement) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:pass_count) }
    it { is_expected.to validate_presence_of(:fail_count) }
    it { is_expected.to validate_presence_of(:pending_count) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:compliance_requirement) }
    it { is_expected.to validate_presence_of(:compliance_framework) }

    it { is_expected.to validate_numericality_of(:pass_count).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:fail_count).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:pending_count).only_integer.is_greater_than_or_equal_to(0) }

    describe 'uniqueness validation' do
      subject { build(:project_requirement_compliance_status) }

      it 'validates uniqueness of project id scoped to requirement id' do
        create(:project_requirement_compliance_status)
        is_expected.to validate_uniqueness_of(:project_id)
                         .scoped_to(:compliance_requirement_id)
                         .with_message('has already been taken')
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      status = create(:project_requirement_compliance_status)
      expect(status).to be_valid
    end
  end
end
