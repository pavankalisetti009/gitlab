# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::DuoSeatsMetric,
  feature_category: :service_ping do
  context 'when there are no active Duo purchases' do
    let(:expected_value) { { pro: { seats: nil, assigned: nil }, enterprise: { seats: nil, assigned: nil } } }

    before do
      allow(GitlabSubscriptions::AddOnPurchase)
        .to receive(:for_gitlab_duo_pro)
        .and_return(GitlabSubscriptions::AddOnPurchase.none)
      allow(GitlabSubscriptions::AddOnPurchase)
        .to receive(:for_duo_enterprise)
        .and_return(GitlabSubscriptions::AddOnPurchase.none)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end

  context 'when there are active Duo purchases' do
    let_it_be(:user) { create(:user) }

    describe 'Duo Pro seats' do
      let(:expected_value) { { pro: { seats: 5, assigned: 1 }, enterprise: { seats: nil, assigned: nil } } }

      let_it_be(:duo_pro_purchase) do
        create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, quantity: 5)
      end

      before do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: duo_pro_purchase
        )
      end

      it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
    end

    describe 'Duo Enterprise seats' do
      let(:expected_value) { { pro: { seats: nil, assigned: nil }, enterprise: { seats: 10, assigned: 1 } } }

      let!(:duo_enterprise_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, quantity: 10)
      end

      before do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: duo_enterprise_purchase
        )
      end

      it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
    end
  end
end
