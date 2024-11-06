# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DiscoverTrialComponent, :aggregate_failures, type: :component, feature_category: :onboarding do
  let(:namespace) { build_stubbed(:namespace) }
  let(:page_scope) { page }
  let(:buy_now_url) { '_purchase_url_' }

  subject(:component) do
    component = described_class.new(namespace: namespace)
    allow(component).to receive(:buy_now_link).and_return(buy_now_url)
    render_inline(component) && page_scope
  end

  context 'when rendering the hero section' do
    let(:page_scope) { find_by_testid('hero-section') }

    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Ship software faster')) }
    it { is_expected.to have_link(_('Buy now'), href: "_purchase_url_") }
    it { is_expected.to have_link(href: 'https://player.vimeo.com/video/855805049?title=0&byline=0&portrait=0&badge=0&autopause=0&player_id=0&app_id=58479') }
  end

  context 'when rendering the why section' do
    let(:page_scope) { find_by_testid('why-section') }

    it { is_expected.to have_content(s_('TrialDiscover|Why Ultimate & GitLab Duo Enterprise?')) }

    it { has_testid?('why-entry', context: component, count: 4) } # rubocop:disable RSpec/NoExpectationExample -- Expectation in matcher

    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Privacy-first AI')) }
    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Boost team collaboration')) }
    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Improve developer experience')) }
    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Transparent AI')) }

    it "correct link is rendered" do
      is_expected.to have_link(_('AI Transparency Center'), href: 'https://about.gitlab.com/ai-transparency-center/')
    end
  end

  context 'when rendering the first core feature section' do
    let(:page_scope) { find_by_testid('core-feature-1') }

    it { has_testid?('core-1-entry', context: component, count: 4) } # rubocop:disable RSpec/NoExpectationExample -- Expectation in matcher

    it { is_expected.to have_content(s_('TrialDiscover|Increase security')) }
    it { is_expected.to have_content(s_('TrialDiscover|Improve collaboration')) }
    it { is_expected.to have_content(s_('TrialDiscover|Gain actionable insights')) }
    it { is_expected.to have_content(s_('TrialDiscover|Enhance productivity')) }
  end

  context 'when rendering the second core feature section' do
    let(:page_scope) { find_by_testid('core-feature-2') }

    it { has_testid?('core-2-entry', context: component, count: 4) } # rubocop:disable RSpec/NoExpectationExample -- Expectation in matcher

    it { is_expected.to have_content(s_('DuoProDiscover|Boost productivity with smart code assistance')) }
    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Fortify your code')) }
    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|GitLab Duo Vulnerability explanation')) }
    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Advanced troubleshooting')) }
  end

  context 'when rendering the footer actions' do
    let(:page_scope) { find_by_testid('discover-footer-actions') }

    it { is_expected.to have_link(_('Buy now'), href: buy_now_url) }
  end

  context 'with trial active and expired concerns' do
    let(:cta_tracking_label) { 'ultimate_active_trial' }
    let(:trial_active?) { true }
    let(:expected_data_attributes) do
      {
        glm_content: 'trial_discover_page',
        cta_tracking: {
          action: 'click_contact_sales',
          label: cta_tracking_label
        }.to_json,
        button_attributes: {
          category: 'secondary',
          variant: 'confirm',
          class: 'gl-w-full sm:gl-w-auto',
          'data-testid': 'trial-discover-hand-raise-lead-button'
        }.to_json
      }
    end

    before do
      allow(namespace).to receive(:ultimate_trial_plan?).and_return(trial_active?)
    end

    context 'when trial is active' do
      it 'has expected hand raise lead data attributes' do
        expect_hand_raise_data_attribute(expected_data_attributes)
      end

      it 'has the correct track action for AI transparency link for the trial status' do
        selector = 'a[href="https://about.gitlab.com/ai-transparency-center/"]' \
          '[data-track-action="click_documentation_link_ultimate_trial_active"]'

        is_expected.to have_selector(selector)
      end

      it 'has correct track label for the buy now links for the trial status' do
        is_expected.to have_selector("a[href='#{buy_now_url}'][data-track-label='#{cta_tracking_label}']", count: 2)
      end
    end

    context 'when trial is expired' do
      let(:cta_tracking_label) { 'ultimate_expired_trial' }
      let(:trial_active?) { false }

      it 'has expected hand raise lead data attributes' do
        expect_hand_raise_data_attribute(expected_data_attributes)
      end

      it 'has the correct track action for AI transparency link for the trial status' do
        selector = 'a[href="https://about.gitlab.com/ai-transparency-center/"]' \
          '[data-track-action="click_documentation_link_ultimate_trial_expired"]'

        is_expected.to have_selector(selector)
      end

      it 'has correct track label for the buy now links for the trial status' do
        is_expected.to have_selector("a[href='#{buy_now_url}'][data-track-label='#{cta_tracking_label}']", count: 2)
      end
    end

    def expect_hand_raise_data_attribute(data_attributes)
      data_attributes.each do |attribute, value|
        is_expected
          .to have_selector(".js-hand-raise-lead-trigger[data-#{attribute.to_s.dasherize}='#{value}']", count: 2)
      end
    end
  end
end
