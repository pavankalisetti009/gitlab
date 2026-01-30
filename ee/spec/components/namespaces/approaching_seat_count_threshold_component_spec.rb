# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::ApproachingSeatCountThresholdComponent, :saas, feature_category: :seat_cost_management do
  let(:namespace) { build(:group, namespace_settings: build(:namespace_settings, seat_control: :off)) }

  let(:total_seat_count) { 2 }
  let(:remaining_seat_count) { 1 }

  let(:element) { find_by_testid('approaching-seat-count-threshold-alert') }

  subject(:component) do
    described_class.new(
      context: namespace,
      remaining_seat_count: remaining_seat_count,
      total_seat_count: total_seat_count
    )
  end

  before do
    render_inline(component)
  end

  it 'renders a warning alert' do
    expect(element).to match_css('.gl-alert')
  end

  it 'shows a title' do
    expect(element).to have_text "#{namespace.name} is approaching the limit of available seats"
  end

  it 'shows an info text' do
    expect(element).to have_text "Your subscription has #{remaining_seat_count} out of #{total_seat_count} " \
      "seats remaining."
    expect(element).to have_text 'Even if you reach the number of seats in your subscription, ' \
      'you can continue to add users, and GitLab will bill you for the overage.'
  end

  it 'contains the correct links' do
    expect(element).to have_link 'Learn more.', href: help_page_path('subscriptions/quarterly_reconciliation.md')
    expect(element).to have_link 'View seat usage', href: usage_quotas_path(namespace, anchor: 'seats-quota-tab')
  end

  it 'has a dismiss button' do
    expect(element).to have_selector('[data-testid="approaching-seat-count-threshold-alert-dismiss"]')
  end

  it 'has the correct dismiss endpoint' do
    expect(element['data-dismiss-endpoint']).to eq(group_callouts_path)
  end

  it 'has the correct feature ID for tracking dismissals' do
    feature_id = Users::GroupCalloutsHelper::APPROACHING_SEAT_COUNT_THRESHOLD
    expect(element['data-feature-id']).to eq(feature_id)
  end

  describe 'pluralization of seat count message' do
    context 'with one seat remaining' do
      let(:remaining_seat_count) { 1 }
      let(:total_seat_count) { 10 }

      it 'uses singular form' do
        expect(element).to have_text 'Your subscription has 1 out of 10 seats remaining.'
      end
    end

    context 'with multiple seats remaining' do
      let(:remaining_seat_count) { 5 }
      let(:total_seat_count) { 10 }

      it 'uses plural form' do
        expect(element).to have_text 'Your subscription has 5 out of 10 seats remaining.'
      end
    end

    context 'with zero seats remaining' do
      let(:remaining_seat_count) { 0 }
      let(:total_seat_count) { 10 }

      it 'uses plural form' do
        expect(element).to have_text 'Your subscription has 0 out of 10 seats remaining.'
      end
    end
  end

  describe 'when restricted access is enabled' do
    let(:namespace) { build(:group, namespace_settings: build(:namespace_settings, seat_control: :block_overages)) }

    it 'shows an info text' do
      expect(element).to have_text 'Once you reach the number of seats in your subscription, you can no longer ' \
        'invite or add users to the namespace.'
    end

    it 'contains the correct links' do
      expect(element).to have_link 'Learn more.', href:
        help_page_path('user/group/manage.md', anchor: 'turn-on-restricted-access')
    end

    it 'still has the view seat usage button' do
      expect(element).to have_link 'View seat usage', href: usage_quotas_path(namespace, anchor: 'seats-quota-tab')
    end
  end

  describe 'when there is no namespace' do
    let(:namespace) { nil }

    it 'does not render the alert' do
      render_inline(component)

      expect(page).not_to have_text "is approaching the limit of available seats"
    end
  end

  describe 'action button' do
    it 'renders the view seat usage button with correct styling' do
      button = element.find_link('View seat usage')
      expect(button['class']).to include('gl-alert-action')
    end

    it 'links to the correct usage quotas page' do
      expect(element).to have_link 'View seat usage', href: usage_quotas_path(namespace, anchor: 'seats-quota-tab')
    end
  end
end
