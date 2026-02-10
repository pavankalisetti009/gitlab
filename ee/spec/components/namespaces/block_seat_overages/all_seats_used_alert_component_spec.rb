# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::BlockSeatOverages::AllSeatsUsedAlertComponent, :saas, feature_category: :seat_cost_management do
  let(:user) { build(:user) }
  let(:namespace) { build(:group) }

  let(:element) { find_by_testid('bso-all-seats-used-alert') }

  subject(:component) do
    described_class.new(
      context: namespace,
      current_user: user
    )
  end

  before do
    allow(user).to receive(:dismissed_callout_for_group?).and_return(false)

    render_inline(component)
  end

  it 'renders a warning alert' do
    expect(element).to match_css('.gl-alert.gl-alert-warning')
  end

  it 'shows a title' do
    expect(element).to have_text "No more seats in subscription"
  end

  it 'shows an info text' do
    expect(element).to have_text "Your namespace has used all the seats in your subscription, " \
      "so users can no longer be invited or added to the namespace. To add new users, " \
      "purchase more seats or turn off restricted access."
  end

  it 'contains the correct links' do
    expect(element).to have_link 'Purchase more seats', href:
      help_page_path('subscriptions/manage_users_and_seats.md', anchor: 'buy-more-seats')
    expect(element).to have_link 'Turn off restricted access', href:
      help_page_path('user/group/manage.md', anchor: 'turn-on-restricted-access')
  end

  context 'when user has dismissed alert' do
    before do
      allow(user).to receive(:dismissed_callout_for_group?).and_return(true)
    end

    it 'does not render the alert' do
      render_inline(component)

      expect(page).not_to have_content('No more seats in subscription')
      expect(page).not_to have_content('Your namespace has used all the seats')
    end
  end
end
