# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DiscoverComponent, :aggregate_failures, :saas, feature_category: :onboarding do
  let(:gitlab_subscription) do
    build_stubbed(:gitlab_subscription, :active_trial,
      trial_starts_on: Date.current - 20.days,
      trial_ends_on: Date.current + 10.days
    )
  end

  let(:namespace) { build_stubbed(:namespace, gitlab_subscription: gitlab_subscription) }

  let(:premium_plan) do
    Hashie::Mash.new(
      code: ::Plan::PREMIUM,
      id: 1,
      name: 'Premium'
    )
  end

  let(:plans_data) { [premium_plan] }

  before do
    allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |service|
      allow(service).to receive(:execute).and_return(plans_data)
    end
  end

  it 'displays the main heading' do
    render_inline(described_class.new(namespace: namespace))
    expect(page).to have_content(s_('BillingPlans|Keep building with GitLab Premium.'))
  end

  it 'displays the trial days remaining message' do
    render_inline(described_class.new(namespace: namespace))
    expect(page).to have_content(
      format(s_('BillingPlans|Your trial has %{days} days left.'), days: 10)
    )
  end

  it 'displays the tagline' do
    render_inline(described_class.new(namespace: namespace))
    expect(page).to have_content(
      s_('BillingPlans|Continue with GitLab Premium to keep shipping faster, together.')
    )
  end

  it 'renders the expert contact component' do
    render_inline(described_class.new(namespace: namespace))
    expect(page).to have_selector('#js-premium-features-section')
  end

  describe 'trial days remaining display' do
    context 'when trial is not active' do
      before do
        allow(namespace).to receive(:trial_active?).and_return(false)
      end

      it 'displays 0 days remaining' do
        render_inline(described_class.new(namespace: namespace))
        expect(page).to have_content(
          format(s_('BillingPlans|Your trial has %{days} days left.'), days: 0)
        )
      end
    end

    context 'when trial is active' do
      it 'displays the correct number of days remaining' do
        render_inline(described_class.new(namespace: namespace))
        expect(page).to have_content(
          format(s_('BillingPlans|Your trial has %{days} days left.'), days: 10)
        )
      end
    end
  end

  describe 'action buttons' do
    before do
      render_inline(described_class.new(namespace: namespace))
    end

    it 'renders upgrade button with correct text' do
      expect(page).to have_content(_('Upgrade'))
    end

    it 'renders upgrade button with correct tracking attributes' do
      attributes = {
        testid: 'upgrade-button',
        action: 'click_cta',
        label: 'upgrade'
      }
      expect(page).to have_tracking(attributes)
    end

    it 'renders explore plans button with correct text' do
      expect(page).to have_content(s_('BillingPlans|Explore plans'))
    end

    it 'renders explore plans button with correct tracking attributes' do
      attributes = {
        testid: 'explore-plans-button',
        action: 'click_cta',
        label: 'explore_paid_plans'
      }
      expect(page).to have_tracking(attributes)
    end
  end
end
