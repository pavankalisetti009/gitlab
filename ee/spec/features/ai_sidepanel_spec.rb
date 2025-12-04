# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Sidepanel', :js, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user, reload: true) { create(:user, :with_namespace) }
  let(:ai_sidepanel_selector) { '.paneled-view.ai-panels' }
  let(:sessions_toggle_selector) { 'ai-sessions-toggle' }

  before_all do
    project.add_developer(user)
    project.project_setting.update!(duo_remote_flows_enabled: true, duo_features_enabled: true)
  end

  before do
    sign_in(user)

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
    allow(::Gitlab::Llm::TanukiBot).to receive(:chat_disabled_reason).and_return(nil)
  end

  context 'when Project Studio IS NOT enabled' do
    before do
      # NOTE: We will stub all existing methods on Users::ProjectStudio to return false, to ensure that
      #       it always is disabled, regardless of how it may be refactored in the future.
      project_studio_instance = instance_double(Users::ProjectStudio, enabled?: false, available?: false)
      allow(Users::ProjectStudio).to receive_messages(new: project_studio_instance, enabled_for_user?: false)
    end

    it 'does not show AI sidepanel' do
      visit project_path(project)
      dismiss_welcome_banner_if_present(page)

      expect(page).not_to have_css(ai_sidepanel_selector)
    end
  end

  context 'when Project Studio IS enabled' do
    before do
      skip 'Test not applicable in classic UI' unless Users::ProjectStudio.enabled_for_user?(user) # rubocop:disable RSpec/AvoidConditionalStatements -- temporary Project Studio rollout
    end

    describe 'sidepanel visibility' do
      it 'shows the AI sidepanel toggle and can expand' do
        # Enable Agentic mode so sessions toggle appears
        set_cookie('duo_agentic_mode_on', 'true')

        visit project_path(project)
        dismiss_welcome_banner_if_present(page)

        expect(page).to have_css(ai_sidepanel_selector)

        expect(page).not_to have_content("Sessions")

        within(ai_sidepanel_selector) do
          find_by_testid(sessions_toggle_selector).click
        end

        # Verify we're now in the agent sessions view
        expect(page).to have_content("Sessions")
      end

      context 'when Project Studio is not enabled for user' do
        before do
          user.update!(new_ui_enabled: false)
        end

        it 'does not show AI sidepanel' do
          visit project_path(project)
          dismiss_welcome_banner_if_present(page)

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
        dismiss_welcome_banner_if_present(page)

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
        dismiss_welcome_banner_if_present(page)
      end

      it 'shows empty state when no sessions exist' do
        within(ai_sidepanel_selector) do
          find_by_testid(sessions_toggle_selector).click
        end

        expect(page).to have_content('No agent sessions yet', wait: 10)
      end

      context 'when duo features are disabled' do
        before do
          project.project_setting.update!(duo_features_enabled: false)
          allow(::Gitlab::Llm::TanukiBot).to receive(:chat_disabled_reason).and_return(:project)
          visit project_path(project)
          dismiss_welcome_banner_if_present(page)
        end

        it 'prevents access to sessions tab' do
          within(ai_sidepanel_selector) do
            sessions_button = find_by_testid(sessions_toggle_selector)

            expect(sessions_button['aria-disabled']).to eq('true')

            sessions_button.click

            expect(page).not_to have_content('No agent sessions yet')
          end
        end
      end
    end
  end
end
