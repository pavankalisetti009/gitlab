# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "groups/add_ons/discover_duo_pro/show", :aggregate_failures, feature_category: :onboarding do
  let(:user) { build_stubbed(:user) }
  let(:group) { build_stubbed(:group) }

  shared_examples 'page expectations' do
    it 'renders the discover duo page hero' do
      expect(rendered).to include(
        s_('DuoProDiscover|Ship software faster and more securely with AI integrated ' \
          'into your entire DevSecOps lifecycle.')
      )
      expect(rendered).to include `data-src="/assets/duo_pro/duo-logo`
      expect(rendered).to include `data-src="/assets/duo_pro/duo-video-thumbnail`
    end

    context 'when rendering the Why GitLab Duo? section' do
      it 'displays the section title' do
        expect(rendered).to have_selector('h3', text: s_('DuoProDiscover|Why GitLab Duo?'))
      end

      it 'renders four card components' do
        expect(rendered).to have_selector('[data-testid="why-gitlab-duo-section"] .gl-card', count: 4)
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

    context "when rendering the What's new in GitLab Duo Chat section" do
      it 'displays the section title' do
        expect(rendered).to have_selector('h3', text: s_("DuoProDiscover|What's new in GitLab Duo Chat"))
      end

      it 'renders four card components' do
        expect(rendered).to have_selector('[data-testid="whats-new-section"] .gl-card', count: 4)
      end

      it 'displays the correct card titles and content' do
        expect(rendered).to have_content(s_("DuoProDiscover|Test Generation"))
        expect(rendered).to have_content(s_("DuoProDiscover|Automates repetitive tasks and helps catch bugs early."))

        expect(rendered).to have_content(s_("DuoProDiscover|Code Explanation"))
        expect(rendered).to have_content(
          s_("DuoProDiscover|Helps you understand code by explaining it in natural language.")
        )

        expect(rendered).to have_content(s_("DuoProDiscover|Code Refactoring"))
        expect(rendered).to have_content(s_("DuoProDiscover|Work to improve existing code quality."))

        expect(rendered).to have_content(s_("DuoProDiscover|Chat from any location"))
        expect(rendered).to have_content(s_("DuoProDiscover|Access Chat from the GitLab UI or your preferred IDE."))
      end
    end

    context 'when rendering the Code Suggestions section' do
      it 'displays the section title' do
        expect(rendered).to have_selector('h3', text: s_("DuoProDiscover|Code Suggestions"))
      end

      it 'renders three card components' do
        expect(rendered).to have_selector('[data-testid="code-suggestions-section"] .gl-card', count: 3)
      end

      it 'displays the correct card titles and content' do
        expect(rendered).to have_content(s_("DuoProDiscover|Code generation"))
        expect(rendered).to have_content(
          s_(<<~CONTENT).squish
            DuoProDiscover|Automatically generate lines of code, including full functions,
            from single and multi-line comments as well as comment blocks.
          CONTENT
        )
        expect(rendered).to have_content(s_("DuoProDiscover|Code completion"))
        expect(rendered).to have_content(
          s_("DuoProDiscover|Automatically generate new lines of code from a few typed characters.")
        )
        expect(rendered).to have_content(s_("DuoProDiscover|Language and IDE support"))
        expect(rendered).to have_content(s_(<<~CONTENT).squish)
          DuoProDiscover|Available in 15 languages, including C++, C#, Go, Java, JavaScript, Python,
          PHP, Ruby, Rust, Scala, Kotlin, and TypeScript. And you can use your favorite IDE —
          VS Code, Visual Studio, JetBrains' suite of IDEs, and Neovim are all supported.
        CONTENT
      end

      it 'includes correct links with tracking' do
        expect(rendered).to have_link(s_("DuoProDiscover|Read documentation"),
          href: help_page_path("user/project/repository/code_suggestions", anchor: "use-code-suggestions"))
        expect(rendered).to have_link(s_("DuoProDiscover|Launch Demo"), href: "https://gitlab.navattic.com/code-suggestions")
      end
    end

    it 'renders the bottom Buy now button' do
      expect(rendered).to have_link(_('Buy now'), href: group_settings_gitlab_duo_usage_index_path(group))
    end
  end

  shared_examples 'tracking expectations' do |trial_status_text|
    it 'has tracking for the buy now button' do
      expect_to_have_tracking(action: 'click_buy_now', label: "duo_pro_#{trial_status_text}_trial")
    end

    it 'has tracking for the contact sales button' do
      expect_to_have_cta_tracking(action: 'click_contact_sales', label: "duo_pro_#{trial_status_text}_trial")
    end

    it 'includes documentation links with correct tracking' do
      expect_to_have_tracking(action: "click_documentation_link_duo_pro_trial_#{trial_status_text}",
        label: 'test_generation_feature')
      expect_to_have_tracking(action: "click_documentation_link_duo_pro_trial_#{trial_status_text}",
        label: 'code_explanation_feature')
      expect_to_have_tracking(action: "click_documentation_link_duo_pro_trial_#{trial_status_text}",
        label: 'code_refactoring_feature')
      expect_to_have_tracking(action: "click_documentation_link_duo_pro_trial_#{trial_status_text}",
        label: 'chat_feature')
    end
  end

  context 'when active trial add-on purchase exists for namespace' do
    before do
      assign(:group, group)
      allow(GitlabSubscriptions::Trials::DuoPro).to receive(:active_add_on_purchase_for_namespace?)
      .with(group).and_return(true)
      render
    end

    include_examples 'page expectations'
    include_examples 'tracking expectations', 'active'
  end

  context 'when active trial add-on purchase does not exist for namespace' do
    before do
      assign(:group, group)
      allow(GitlabSubscriptions::Trials::DuoPro).to receive(:active_add_on_purchase_for_namespace?)
      .with(group).and_return(false)
      render
    end

    include_examples 'page expectations'
    include_examples 'tracking expectations', 'expired'
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
