# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::AdvantagesListComponent, :aggregate_failures, feature_category: :acquisition do
  subject(:component) { described_class.new }

  it 'renders the component with all expected elements' do
    render_inline(component)

    within(find_by_testid('trial-reassurances-column')) do
      expect(page).to have_css('img')
    end

    expect(page).to have_content(s_('InProductMarketing|No credit card required.'))

    expected_advantage_count = 4
    expect(all_by_testid('advantage-item').count).to eq(expected_advantage_count)
    expect(all_by_testid('check-circle-icon').count).to eq(expected_advantage_count)
  end

  context 'when ultimate_trial_with_dap feature flag is enabled' do
    before do
      stub_feature_flags(ultimate_trial_with_dap: true)
    end

    it 'renders Duo Agent Platform heading' do
      render_inline(component)

      expect(page).to have_content(
        s_('InProductMarketing|Accelerate delivery with GitLab Ultimate + GitLab Duo Agent Platform')
      )
    end

    it 'renders support compliance advantage' do
      render_inline(component)

      expect(page).to have_content(s_('InProductMarketing|Support compliance'))
    end
  end

  context 'when ultimate_trial_with_dap feature flag is disabled' do
    before do
      stub_feature_flags(ultimate_trial_with_dap: false)
    end

    it 'renders Duo Enterprise heading' do
      render_inline(component)

      expect(page).to have_content(
        s_('InProductMarketing|Experience the power of Ultimate + GitLab Duo Enterprise')
      )
    end

    it 'renders ensure compliance advantage' do
      render_inline(component)

      expect(page).to have_content(s_('InProductMarketing|Ensure compliance'))
    end
  end
end
