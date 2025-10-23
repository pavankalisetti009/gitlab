# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Sidepanel', :js, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, :with_namespace) }
  let(:ai_sidepanel_selector) { '.paneled-view.ai-panels' }
  let(:sessions_toggle_selector) { 'ai-sessions-toggle' }

  before_all do
    project.add_developer(user)
    project.project_setting.update!(duo_remote_flows_enabled: true, duo_features_enabled: true)
  end

  before do
    sign_in(user)

    stub_feature_flags(paneled_view: true, tailwind_container_queries: true)
    user.update!(project_studio_enabled: true)

    project_studio_instance = instance_double(Users::ProjectStudio, enabled?: true, available?: true)
    allow(Users::ProjectStudio).to receive(:new).and_return(project_studio_instance)

    create(:callout, user: user, feature_name: :duo_chat_callout)

    stub_feature_flags(duo_workflow_in_ci: true, duo_workflow: true)
    stub_licensed_features(ai_workflows: true)
    allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(true)
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)

    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, :read_duo_workflow, anything).and_return(true)
    allow(Ability).to receive(:allowed?).with(user, :duo_workflow, anything).and_return(true)

    allow(::Ai::AmazonQ).to receive(:enabled?).and_return(false)
    allow(::Gitlab::Llm::TanukiBot).to receive_messages(show_breadcrumbs_entry_point?: true, enabled_for?: true)
  end

  describe 'sidepanel visibility' do
    it 'shows the AI sidepanel toggle and can expand' do
      # Enable Agentic mode so sessions toggle appears
      set_cookie('duo_agentic_mode_on', 'true')

      visit project_path(project)

      expect(page).to have_css(ai_sidepanel_selector)

      expect(page).not_to have_content("Sessions")

      within(ai_sidepanel_selector) do
        find_by_testid(sessions_toggle_selector).click
      end

      # Verify we're now in the agent sessions view
      expect(page).to have_content("Sessions")
    end

    context 'when Project Studio is not available' do
      before do
        stub_feature_flags(paneled_view: false)

        project_studio_instance = instance_double(Users::ProjectStudio, enabled?: false, available?: false)
        allow(Users::ProjectStudio).to receive(:new).and_return(project_studio_instance)
      end

      it 'does not show AI sidepanel' do
        visit project_path(project)

        expect(page).not_to have_css(ai_sidepanel_selector)
      end
    end

    context 'when Project Studio is not enabled for user' do
      before do
        user.update!(project_studio_enabled: false)

        project_studio_instance = instance_double(Users::ProjectStudio, enabled?: false, available?: false)
        allow(Users::ProjectStudio).to receive(:new).and_return(project_studio_instance)
      end

      it 'does not show AI sidepanel' do
        visit project_path(project)

        expect(page).not_to have_css(ai_sidepanel_selector)
      end
    end
  end

  describe 'agent sessions in sidepanel' do
    let_it_be(:workflow1) do
      create(:duo_workflows_workflow,
        project: project,
        user: user,
        goal: 'Fix pipeline issues',
        workflow_definition: 'issue_to_mr',
        environment: :web)
    end

    let_it_be(:workflow2) do
      create(:duo_workflows_workflow,
        project: project,
        user: user,
        goal: 'Review code changes',
        workflow_definition: 'code_review',
        environment: :web)
    end

    before do
      # Enable Agentic mode so sessions toggle appears
      set_cookie('duo_agentic_mode_on', 'true')

      visit project_path(project)

      within(ai_sidepanel_selector) do
        find_by_testid(sessions_toggle_selector).click
      end
    end

    it 'displays the sessions list' do
      expect(page).to have_content("Issue to mr ##{workflow1.id}")
      expect(page).to have_content("Code review ##{workflow2.id}")
    end

    it 'navigates to session details when clicked' do
      expect(page).not_to have_content('Activity')
      expect(page).not_to have_content('Details')

      expect(page).to have_selector('a[href*="/agent-sessions/"]')
      find('a[href*="/agent-sessions/"]', match: :first).click

      expect(page).to have_content('Activity')
      expect(page).to have_content('Details')

      expect(page).to have_selector('.gl-tab-nav-item.active', text: 'Activity')
      expect(page).to have_no_content('GraphQL error:')
    end

    it 'can view session details tab' do
      find('a[href*="/agent-sessions/"]', match: :first).click

      click_link 'Details'

      expect(page).to have_content('Details')
      expect(page).to have_content(project.name)
      expect(page).to have_no_content('GraphQL error:')
    end
  end

  describe 'agent sessions empty state in sidepanel' do
    before do
      Ai::DuoWorkflows::Workflow.where(project: project, user: user).delete_all

      # Enable Agentic mode so sessions toggle appears
      set_cookie('duo_agentic_mode_on', 'true')

      visit project_path(project)

      within(ai_sidepanel_selector) do
        find_by_testid(sessions_toggle_selector).click
      end
    end

    it 'shows empty state when no sessions exist' do
      expect(page).to have_content('No agent sessions yet', wait: 10)
    end
  end
end
