# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ApprovalPolicyRuleProjectLink, feature_category: :security_policy_management do
  subject { create(:approval_policy_rule_project_link) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:approval_policy_rule) }

    it { is_expected.to validate_uniqueness_of(:approval_policy_rule).scoped_to(:project_id) }
  end
end
