# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::AllSeatsUsedAlertComponent, :saas, feature_category: :seat_cost_management do
  include ReactiveCachingHelpers

  let(:user) { build_stubbed(:user, :with_namespace) }
  let(:namespace) { build(:group, namespace_settings: build(:namespace_settings, seat_control: :off)) }

  let(:classes) { nil }
  let(:billable_members_count) { 2 }
  let(:permission_owner) { true }

  let(:element) { find_by_testid('all-seats-used-alert') }

  subject(:component) do
    described_class.new(
      context: namespace,
      content_class: classes,
      current_user: user
    )
  end

  before do
    allow(namespace).to receive(:billable_members_count).and_return(billable_members_count)
    allow(Ability).to receive(:allowed?).with(user, :owner_access, namespace).and_return(permission_owner)

    build(:gitlab_subscription, namespace: namespace, plan_code: Plan::ULTIMATE, seats: 2)
  end

  shared_examples_for 'not rendering the alert' do
    it 'does not render the alert' do
      render_inline(component)

      expect(page).not_to have_content('Your namespace has used all the seats')
    end
  end

  shared_examples_for 'rendering the alert' do
    before do
      render_inline(component)
    end

    it 'renders a warning alert' do
      expect(element).to match_css('.gl-alert.gl-alert-warning')
    end

    it 'shows a title' do
      expect(element).to have_text "No more seats in subscription"
    end

    it 'shows an info text' do
      expect(element).to have_text "Your namespace has used all the seats in your subscription. " \
        "To avoid overages from adding new users, consider turning on restricted access, or purchase more seats."
    end

    it 'contains the correct links' do
      expect(element).to have_link 'turning on restricted access', href:
        help_page_path('user/group/manage.md', anchor: 'turn-on-restricted-access')
      expect(element).to have_link 'purchase more seats', href:
        help_page_path('subscriptions/manage_users_and_seats.md', anchor: 'buy-more-seats')
    end
  end

  context 'with a reactive cache hit' do
    before do
      synchronous_reactive_cache(namespace)
    end

    describe 'with custom classes' do
      let(:classes) { 'test-class' }

      it 'adds custom class to the alert' do
        render_inline(component)

        expect(element).to match_css('.test-class')
      end
    end

    describe 'when namespace has no paid plan' do
      before do
        build(:gitlab_subscription, namespace: namespace, plan_code: Plan::FREE)
      end

      it_behaves_like 'not rendering the alert'
    end

    describe 'when user is not a owner' do
      let(:permission_owner) { false }

      it_behaves_like 'not rendering the alert'
    end

    describe 'when block seats overages is enabled' do
      let(:namespace) do
        build(:group, namespace_settings: build(:namespace_settings, seat_control: :block_overages))
      end

      it_behaves_like 'not rendering the alert'
    end

    describe 'with no billable members' do
      let(:billable_members_count) { 0 }

      it_behaves_like 'not rendering the alert'
    end

    describe 'when namespace is personal' do
      let(:namespace) { build(:user, :with_namespace).namespace }

      it_behaves_like 'not rendering the alert'
    end

    context 'with notify_all_seats_used disabled' do
      before do
        stub_feature_flags(notify_all_seats_used: false)
      end

      it_behaves_like 'not rendering the alert'
    end

    describe 'with more billable members than seats' do
      let(:billable_members_count) { 3 }

      it_behaves_like 'rendering the alert'
    end

    it_behaves_like 'rendering the alert'
  end

  context 'with a reactive cache miss' do
    before do
      stub_reactive_cache(namespace, nil)
    end

    it_behaves_like 'not rendering the alert'
  end
end
