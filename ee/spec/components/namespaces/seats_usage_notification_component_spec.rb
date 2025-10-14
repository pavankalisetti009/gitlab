# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::SeatsUsageNotificationComponent, :saas, feature_category: :seat_cost_management do
  include ReactiveCachingHelpers

  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:namespace) do
    build_stubbed(:group, namespace_settings: build(:namespace_settings, seat_control: :off))
  end

  let(:billable_members_count) { 13 }
  let(:total_seat_count) { 13 }

  let(:kwargs) { { context: namespace, current_user: user } }

  subject(:component) { render_inline(described_class.new(**kwargs)) && page }

  before do
    allow(namespace).to receive(:billable_members_count).and_return(billable_members_count)

    build(:gitlab_subscription, namespace: namespace, plan_code: Plan::ULTIMATE, seats: total_seat_count)
  end

  shared_examples 'does not render any notification' do
    it 'does not render an alert' do
      is_expected.not_to have_selector('[data-testid="all-seats-used-alert"]')
      is_expected.not_to have_selector('[data-testid="bso-all-seats-used-alert"]')
    end

    it 'does not contain any text title' do
      is_expected.not_to have_text('Your namespace has used all the seats')
    end
  end

  shared_examples 'renders the all seats used notification' do
    it 'does render the correct alert' do
      is_expected.to have_selector('[data-testid="all-seats-used-alert"]')
    end

    it 'shows the correct title' do
      is_expected.to have_text('Your namespace has used all the seats')
    end

    context 'with notify_all_seats_used disabled' do
      before do
        stub_feature_flags(notify_all_seats_used: false)
      end

      it_behaves_like 'does not render any notification'
    end

    context 'with restricted access enabled' do
      let_it_be(:namespace) do
        build_stubbed(:group, namespace_settings: build(:namespace_settings, seat_control: :block_overages))
      end

      it 'does render the correct alert' do
        is_expected.to have_selector('[data-testid="bso-all-seats-used-alert"]')
      end

      it 'shows the correct title' do
        is_expected.to have_text('Your namespace has used all the seats')
      end
    end
  end

  context 'with a reactive cache hit' do
    before do
      synchronous_reactive_cache(namespace)
    end

    describe 'when user is an owner' do
      before do
        stub_member_access_level(namespace, owner: user)
      end

      describe 'when namespace has no paid plan' do
        before do
          build(:gitlab_subscription, namespace: namespace, plan_code: Plan::FREE)
        end

        it_behaves_like 'does not render any notification'
      end

      describe 'with no billable members' do
        let(:billable_members_count) { 0 }

        it_behaves_like 'does not render any notification'
      end

      describe 'with more billable members than seats' do
        let(:billable_members_count) { 16 }

        it_behaves_like 'renders the all seats used notification'
      end

      it_behaves_like 'renders the all seats used notification'
    end

    describe 'when namespace is personal' do
      let(:namespace) { build(:user_namespace) }

      it_behaves_like 'does not render any notification'
    end

    it_behaves_like 'does not render any notification'
  end

  context 'with a reactive cache miss' do
    before do
      stub_reactive_cache(namespace, nil)
    end

    it_behaves_like 'does not render any notification'
  end
end
