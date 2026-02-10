# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::AllSeatsUsedAlertComponent, :saas, feature_category: :seat_cost_management do
  let(:namespace) { build(:group, namespace_settings: build(:namespace_settings, seat_control: :off)) }

  let(:billable_members_count) { 2 }
  let(:permission_owner) { true }

  let(:element) { find_by_testid('all-seats-used-alert') }

  subject(:component) { described_class.new(context: namespace) }

  before do
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
        "To avoid overages from adding new users, purchase more seats or turn on restricted access."
    end

    it 'contains the correct links' do
      expect(element).to have_link 'Purchase more seats', href:
        help_page_path('subscriptions/manage_users_and_seats.md', anchor: 'buy-more-seats')
      expect(element).to have_link 'Turn on restricted access', href:
        help_page_path('user/group/manage.md', anchor: 'turn-on-restricted-access')
    end
  end

  context 'when namespace has no paid plan' do
    before do
      build(:gitlab_subscription, namespace: namespace, plan_code: Plan::FREE)
    end

    it_behaves_like 'not rendering the alert'
  end

  context 'with notify_all_seats_used disabled' do
    before do
      stub_feature_flags(notify_all_seats_used: false)
    end

    it_behaves_like 'not rendering the alert'
  end

  it_behaves_like 'rendering the alert'
end
