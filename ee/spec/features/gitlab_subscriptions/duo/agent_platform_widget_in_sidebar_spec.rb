# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo GitLab Duo Core widget in Sidebar', :js, feature_category: :activation do
  shared_examples_for 'Duo GitLab Duo Core progressive enabling' do
    it 'performs progressive enabling of the Duo agent platform' do
      visit path

      expect_widget_to_have_content(s_('DuoAgentPlatform|GitLab Duo Core Off'))
      expect_widget_to_have_content(_('Team requests'))

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
  end

  shared_examples_for 'Duo GitLab Duo Core requestor' do
    it 'performs request for the Duo GitLab Duo Core enablement' do
      visit path

      expect_widget_to_have_content(s_('DuoAgentPlatform|GitLab Duo Core Off'))
      expect_widget_to_have_content(_('Request'))

      widget_request

      expect_widget_to_have_content(_('Requested'))

      page.refresh

      expect_widget_to_have_content(s_('DuoAgentPlatform|GitLab Duo Core Off'))
      expect_widget_to_have_content(_('Requested'))
    end
  end

  context 'when gitlab_duo_saas_only is disabled', time_travel_to: Date.new(2025, 9, 18) do
    let(:path) { root_path }

    before_all do
      create(:application_setting, duo_availability: 'default_off')
      create(:ai_settings, duo_agent_platform_service_url: '', duo_core_features_enabled: false,
        duo_agent_platform_request_count: 1)
    end

    before do
      stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
      stub_saas_features(gitlab_duo_saas_only: false)
      stub_licensed_features(code_suggestions: true)
      sign_in(user)
    end

    context 'when authorized', :enable_admin_mode do
      let_it_be(:user) { create(:admin) }

      it_behaves_like 'Duo GitLab Duo Core progressive enabling'
    end

    context 'when requestor' do
      let_it_be(:user) { create(:user) }

      it_behaves_like 'Duo GitLab Duo Core requestor'
    end
  end

  context 'when gitlab_duo_saas_only is enabled', :saas do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) do
      create(:group_with_plan, :with_duo_never_on, plan: :ultimate_plan) do |g|
        create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: g)
      end
    end

    let(:path) { group_path(namespace) }

    before do
      stub_application_setting(check_namespace_plan: true)
      stub_saas_features(gitlab_duo_saas_only: true)
      stub_licensed_features(code_suggestions: true)
      sign_in(user)
    end

    context 'when authorized' do
      before_all do
        namespace.add_owner(user)
      end

      it 'performs progressive enabling of the Duo agent platform' do
        visit path

        expect_widget_to_have_content(s_('DuoAgentPlatform|GitLab Duo Core Off'))
        # expect_widget_to_have_content(_('Team requests'))

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
    end
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

  def widget_request
    within_testid(widget_menu_selector) do
      click_button(_('Request'))
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
