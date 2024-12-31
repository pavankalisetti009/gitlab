# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::ProvisionSync, feature_category: :plan_provisioning do
  subject { build(:gitlab_subscription_provision_sync) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:sync_requested_at) }
    it { is_expected.to validate_presence_of(:attrs) }

    it { is_expected.to validate_uniqueness_of(:namespace_id).scoped_to(:sync_requested_at) }
  end
end
