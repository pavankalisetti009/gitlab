# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokenPolicy, feature_category: :permissions do
  include AdminModeHelper

  subject { described_class.new(current_user, token) }

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let(:token) { create(:personal_access_token, user: user) }

  before do
    stub_licensed_features(domain_verification: true)
  end

  context 'when the token is owned by non-enterprise user' do
    let_it_be(:user) { create(:user) }

    before_all do
      group.add_developer(user)
    end

    context 'when the current user is a group owner' do
      before_all do
        group.add_owner(current_user)
      end

      it { is_expected.to be_disallowed(:revoke_token) }
    end
  end

  context 'when the token is owned by an enterprise user on GitLab.com', :saas do
    let_it_be(:user) { create(:enterprise_user, enterprise_group: group) }

    before_all do
      group.add_developer(user)
    end

    context 'when the current user is a maintainer' do
      before_all do
        group.add_maintainer(current_user)
      end

      it { is_expected.to be_disallowed(:revoke_token) }
    end

    context 'when the current user is a group owner' do
      before_all do
        group.add_owner(current_user)
      end

      it { is_expected.to be_allowed(:revoke_token) }

      context 'when domain verification is not available' do
        before do
          stub_licensed_features(domain_verification: false)
        end

        it { is_expected.to be_disallowed(:revoke_token) }
      end
    end
  end
end
