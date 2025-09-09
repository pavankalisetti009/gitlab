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

    it { is_expected.to validate_presence_of(:security_findings_uuids) }
    it { is_expected.to(validate_uniqueness_of(:merge_request_id).scoped_to(%i[security_policy_id])) }
  end
end
