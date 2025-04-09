# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserAdminRole, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:admin_role).class_name('Authz::AdminRole') }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validation' do
    subject(:user_admin_role) { build(:user_admin_role) }

    it { is_expected.to validate_presence_of(:admin_role) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_uniqueness_of(:user) }
  end
end
