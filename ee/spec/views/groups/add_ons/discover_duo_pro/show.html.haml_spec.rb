# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/add_ons/discover_duo_pro/show', :aggregate_failures, feature_category: :onboarding do
  let(:group) { build_stubbed(:group) }

  before do
    assign(:group, group)
  end

  subject { render && rendered }

  it { is_expected.to have_link(_('Buy now'), href: group_settings_gitlab_duo_usage_index_path(group), count: 2) }

  context 'when rendering the hero section' do
    it { is_expected.to include(s_('DuoProDiscover|Ship software faster')) }
  end

  context 'when rendering the Why GitLab Duo? section' do
    it { is_expected.to include(s_('DuoProDiscover|Why GitLab Duo Pro?')) }

    it { is_expected.to have_selector('[data-testid="why-section"] .gl-card', count: 4) }

    it { is_expected.to have_content(s_('DuoProDiscover|Privacy-first AI')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Boost team collaboration')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Improve developer experience')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Transparent AI')) }

    it do
      is_expected.to have_link(_('AI Transparency Center'), href: 'https://about.gitlab.com/ai-transparency-center/')
    end
  end

  context 'when rendering the first core feature section' do
    it { is_expected.to have_content(s_('DuoProDiscover|Boost productivity with smart code assistance')) }

    it { is_expected.to have_selector('[data-testid="core-feature-1"] .gl-card', count: 4) }

    it { is_expected.to have_content(s_('DuoProDiscover|Automate mundane tasks')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Catch bugs early in the workflow')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Real-time guidance')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Use Chat to get up to speed')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Modernize code faster')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Refactor code into modern')) }
  end
end
