# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::Admin, feature_category: :permissions do
  subject(:instance_authorization) { described_class.new(user) }

  let_it_be(:user) { create(:user) }

  let_it_be(:admin_role) { create(:member_role, :admin) }
  let_it_be(:user_member_role) { create(:user_member_role, member_role: admin_role, user: user) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe "#permitted" do
    subject(:permitted) { instance_authorization.permitted }

    it 'includes the ability' do
      is_expected.to eq([:read_admin_dashboard])
    end
  end
end
