# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::ScimGroupMembership, type: :model, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:user).optional(false) }
  end

  describe 'validations' do
    subject { build(:scim_group_membership) }

    it { is_expected.to validate_presence_of(:scim_group_uid) }
    it { is_expected.to validate_uniqueness_of(:user).scoped_to(:scim_group_uid) }
  end
end
