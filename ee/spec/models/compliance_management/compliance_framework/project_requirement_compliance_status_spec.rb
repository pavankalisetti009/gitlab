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

  describe '.order_by_updated_at_and_id' do
    let_it_be(:group) { create(:group) }
    let_it_be(:framework) { create(:compliance_framework, namespace: group) }
    let_it_be(:requirement1) { create(:compliance_requirement, namespace: group, framework: framework) }
    let_it_be(:requirement2) do
      create(:compliance_requirement, namespace: group, framework: framework, name: 'requirement2')
    end

    let_it_be(:requirement3) do
      create(:compliance_requirement, namespace: group, framework: framework, name: 'requirement3')
    end

    let_it_be(:project) { create(:project, namespace: group) }

    let_it_be(:requirement_status1) do
      create(:project_requirement_compliance_status, compliance_requirement: requirement1, project: project,
        updated_at: 1.day.ago)
    end

    let_it_be(:requirement_status2) do
      create(:project_requirement_compliance_status, compliance_requirement: requirement2, project: project,
        updated_at: 1.week.ago)
    end

    let_it_be(:requirement_status3) do
      create(:project_requirement_compliance_status, compliance_requirement: requirement3, project: project,
        updated_at: 2.days.ago)
    end

    context 'when direction is not provided' do
      it 'sorts by updated_at in ascending order by default' do
        expect(described_class.order_by_updated_at_and_id).to eq(
          [
            requirement_status2,
            requirement_status3,
            requirement_status1
          ]
        )
      end
    end

    context 'when direction is asc' do
      it 'sorts by updated_at in ascending order by default' do
        expect(described_class.order_by_updated_at_and_id(:asc)).to eq(
          [
            requirement_status2,
            requirement_status3,
            requirement_status1
          ]
        )
      end
    end

    context 'when direction is desc' do
      it 'sorts in descending order' do
        expect(described_class.order_by_updated_at_and_id(:desc)).to eq(
          [
            requirement_status1,
            requirement_status3,
            requirement_status2
          ]
        )
      end
    end

    context 'when direction is invalid' do
      it 'raises error' do
        expect do
          described_class.order_by_updated_at_and_id(:invalid)
        end.to raise_error(ArgumentError, /Direction "invalid" is invalid/)
      end
    end
  end
end
