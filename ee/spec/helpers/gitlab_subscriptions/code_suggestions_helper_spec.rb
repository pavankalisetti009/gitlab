# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::CodeSuggestionsHelper, feature_category: :seat_cost_management do
  include SubscriptionPortalHelper

  describe '#duo_pro_bulk_user_assignment_available?' do
    context 'when GitLab is .com' do
      let_it_be(:namespace) { build_stubbed(:group) }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when duo pro is available' do
        it 'returns true' do
          expect(helper.duo_pro_bulk_user_assignment_available?(namespace)).to be_truthy
        end
      end
    end

    context 'when GitLab is self managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'returns true' do
        expect(helper.duo_pro_bulk_user_assignment_available?).to be_truthy
      end

      context 'when sm_duo_pro_bulk_user_assignment feature flag is disabled' do
        before do
          stub_feature_flags(sm_duo_pro_bulk_user_assignment: false)
        end

        it 'returns false' do
          expect(helper.duo_pro_bulk_user_assignment_available?).to be_falsey
        end
      end
    end
  end

  describe '#add_duo_pro_seats_url' do
    let(:subscription_name) { 'A-S000XXX' }
    let(:env_value) { nil }

    before do
      stub_env('CUSTOMER_PORTAL_URL', env_value)
    end

    it 'returns expected url' do
      expected_url = "#{staging_customers_url}/gitlab/subscriptions/#{subscription_name}/duo_pro_seats"
      expect(helper.add_duo_pro_seats_url(subscription_name)).to eq expected_url
    end
  end
end
