# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus, type: :model,
  feature_category: :compliance_management do
  describe 'associations' do
    it { is_expected.to belong_to(:compliance_requirements_control) }
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:compliance_requirement) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:compliance_requirement) }
    it { is_expected.to validate_presence_of(:compliance_requirements_control) }

    describe 'uniqueness validation' do
      subject { build(:project_control_compliance_status) }

      it 'validates uniqueness of project id scoped to control id' do
        create(:project_control_compliance_status)
        is_expected.to validate_uniqueness_of(:project_id)
          .scoped_to(:compliance_requirements_control_id)
          .with_message('has already been taken')
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(pass: 0, fail: 1) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      status = create(:project_control_compliance_status)
      expect(status).to be_valid
    end
  end
end
