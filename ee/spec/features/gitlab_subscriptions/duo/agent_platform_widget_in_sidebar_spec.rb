# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo agent platform widget in Sidebar', :enable_admin_mode, :js, feature_category: :activation do
  let_it_be(:user) { create(:admin) }

  before_all do
    create(:application_setting, duo_availability: 'default_off')
    create(:ai_settings, duo_agent_platform_service_url: '', duo_core_features_enabled: false)
  end

  around do |example|
    travel_to(Date.new(2025, 9, 18))
    example.run
    travel_back
  end

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    stub_saas_features(gitlab_duo_saas_only: false)
    stub_licensed_features(code_suggestions: true)
    sign_in(user)
  end

  it 'performs progressive enabling of Duo Core' do
    visit root_path

    expect_widget_to_have_content(s_('DuoAgentPlatform|GitLab Duo Core Off'))

    widget_turn_on
    confirm_modal_turn_on

    expect_widget_to_have_content(s_('DuoAgentPlatform|GitLab Duo Core On'))

    page.refresh

    expect_widget_to_have_content(s_('DuoAgentPlatform|GitLab Duo Core On'))
    expect_widget_to_have_content(s_('DuoAgentPlatform|Access the latest GitLab Duo features'))

    widget_turn_on_preview
    confirm_modal_turn_on

    expect_widget_not_to_have_content(s_('DuoAgentPlatform|Access the latest GitLab Duo features'))

    page.refresh

    expect_widget_to_have_content(s_('DuoAgentPlatform|GitLab Duo Core On'))
    expect_widget_not_to_have_content(s_('DuoAgentPlatform|Access the latest GitLab Duo features'))
  end

  def expect_widget_to_have_content(widget_title)
    within_testid(widget_menu_selector) do
      expect(page).to have_content(widget_title)
    end
  end

  def expect_widget_not_to_have_content(widget_title)
    within_testid(widget_menu_selector) do
      expect(page).not_to have_content(widget_title)
    end
  end

  def widget_turn_on
    within_testid(widget_menu_selector) do
      click_button(_('Turn on'))
    end
  end

  def widget_turn_on_preview
    within_testid(widget_menu_selector) do
      click_button(_('Learn more'))
    end
  end

  def confirm_modal_turn_on
    within_testid('confirm-modal') do
      click_button(_('Turn on'))
    end
  end

  def widget_menu_selector
    'duo-agent-platform-widget-menu'
  end
end
