# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicyDismissal, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project).required }
    it { is_expected.to belong_to(:merge_request).required }
    it { is_expected.to belong_to(:security_policy).required }
    it { is_expected.to belong_to(:user).optional }
  end

  describe 'validations' do
    subject(:policy_dismissal) { create(:policy_dismissal) }

    it { is_expected.to allow_value(nil).for(:security_findings_uuids) }
    it { is_expected.to validate_length_of(:comment).is_at_most(255).allow_nil }

    it { is_expected.to(validate_uniqueness_of(:merge_request_id).scoped_to(%i[security_policy_id])) }

    context 'when validating dismissal_types' do
      it 'is invalid if empty' do
        policy_dismissal.dismissal_types = []
        expect(policy_dismissal).not_to be_valid
        expect(policy_dismissal.errors[:dismissal_types]).to include(/must be an array with allowed values/)
      end

      it 'is invalid if includes unknown value' do
        policy_dismissal.dismissal_types = described_class::DISMISSAL_TYPES.values + [999]
        expect(policy_dismissal).not_to be_valid
        expect(policy_dismissal.errors[:dismissal_types]).to include(/must be an array with allowed values/)
      end

      it 'is valid if all values are allowed' do
        policy_dismissal.dismissal_types = described_class::DISMISSAL_TYPES.values.sample(2)
        expect(policy_dismissal).to be_valid
      end
    end
  end
end
