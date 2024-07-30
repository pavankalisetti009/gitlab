# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "groups/add_ons/discover_duo_pro/show", :aggregate_failures, feature_category: :onboarding do
  let(:user) { build_stubbed(:user) }
  let(:group) { build_stubbed(:group) }

  before do
    assign(:group, group)
    allow(view).to receive(:duo_pro_trial_status_track_action)
      .with(group)
      .and_return('click_documentation_link_duo_pro_trial_active')
    render
  end

  it 'renders the discover duo page hero' do
    expect(rendered).to have_text(
      s_(
        'DuoProDiscover|Ship software faster and more securely with AI integrated into your entire DevSecOps lifecycle.'
      )
    )
    expect(rendered).to include `data-src="/assets/duo_pro/duo-logo`
    expect(rendered).to include `data-src="/assets/duo_pro/duo-video-thumbnail`
  end

  context 'with tracking' do
    it 'has tracking for the buy now button' do
      expect_to_have_tracking(action: 'click_buy_now', label: 'duo_pro_active_trial')
    end

    it 'has tracking for the contact sales button' do
      expect_to_have_cta_tracking(action: 'click_contact_sales', label: 'duo_pro_active_trial')
    end
  end

  context 'when rendering the Why GitLab Duo? section' do
    it 'displays the section title' do
      expect(rendered).to have_text(s_('DuoProDiscover|Why GitLab Duo?'))
    end

    it 'renders four card components' do
      expect(rendered).to have_css('.gl-grid-cols-1.md\\:gl-grid-cols-2 > .gl-card', count: 4)
    end

    it 'displays the correct card titles' do
      expect(rendered).to have_content(s_("DuoProDiscover|Accelerate your path to market"))
      expect(rendered).to have_content(s_("DuoProDiscover|Adopt AI with guardrails"))
      expect(rendered).to have_content(s_("DuoProDiscover|Improve developer experience"))
      expect(rendered).to have_content(s_("DuoProDiscover|Committed to transparent AI"))
    end

    it 'includes a link to the AI Transparency Center' do
      expect(rendered).to have_link(_("AI Transparency Center"), href: "https://about.gitlab.com/ai-transparency-center/")
    end
  end

  context 'with documentation link click tracking' do
    it 'has tracking for the AI Transparency documentation link' do
      expect_to_have_tracking(action: 'click_documentation_link_duo_pro_trial_active',
        label: 'ai_transparency_center_feature')
    end
  end

  def expect_to_have_cta_tracking(action:, label:)
    css = `data-tracking={"action": #{action}, "label": #{label}}`
    expect(rendered).to include(css)
  end

  def expect_to_have_tracking(action:, label:)
    selector = "a[data-track-action='#{action}']" \
      "[data-track-label='#{label}']"
    expect(rendered).to have_css(selector)
  end
end
