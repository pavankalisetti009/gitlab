# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat > User opens Duo Chat', :js, :saas, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, :public, group: group) }

  before_all do
    group.add_developer(user)
  end

  before do
    allow(::Gitlab::Llm::TanukiBot).to receive(:credits_available?).and_return(true)
    allow(user).to receive(:allowed_to_use?).and_return(true)
    allow(user).to receive(:can?).and_call_original

    sign_in(user)
  end

  describe 'Duo Chat' do
    context 'with the drawer closed' do
      before do
        visit project_path(project)
        find('button.js-tanuki-bot-chat-toggle').click
        wait_for_requests
      end

      it 'shows the Duo Chat button' do
        expect(page).to have_selector('button.js-tanuki-bot-chat-toggle')
      end

      it 'opens Duo Chat drawer when button is clicked' do
        expect(page).to have_css('.ai-panel')
      end

      it 'focuses the duo chat input' do
        expect(page).to have_css('[data-testid="chat-prompt-input"]', focused: true)
      end
    end

    context 'with the drawer open' do
      before do
        visit project_path(project)
        find('button.js-tanuki-bot-chat-toggle').click
        wait_for_requests

        page.refresh
        sign_in(user)
        visit project_path(project)
        wait_for_requests
      end

      it 'keeps the drawer open' do
        expect(page).to have_css('.ai-panel')
      end

      it 'does not focus the duo chat input' do
        expect(page).to have_css('[data-testid="chat-prompt-input"]', focused: false)
      end
    end
  end

  describe 'closing Duo Chat' do
    before do
      visit project_path(project)
      find('button.js-tanuki-bot-chat-toggle').click
      wait_for_requests
    end

    it 'closes Duo Chat drawer when close button is clicked' do
      within_testid('duo-chat-promo-callout-popover') { find_by_testid('close-icon').click }

      find_by_testid('content-container-collapse-button').click

      expect(page).not_to have_css('.ai-panel')
    end
  end

  describe 'opening Duo Chat from Action button' do
    let_it_be(:pipeline) do
      create(
        :ci_pipeline,
        project: project,
        user: user
      )
    end

    let_it_be(:build) { create(:ci_build, :trace_artifact, :failed, pipeline: pipeline) }

    before do
      stub_licensed_features(ai_features: true, troubleshoot_job: true)

      allow(project).to receive(:duo_features_enabled).and_return(true)
      allow(user).to receive(:assigned_to_duo_add_ons?).with(project).and_return(true)
      allow(user).to receive(:assigned_to_duo_core?).with(project).and_return(false)

      visit project_job_path(project, build)
    end

    it 'opens Duo Chat with troubleshoot prompt when Troubleshoot button is clicked' do
      find_by_testid('rca-duo-button').click
      wait_for_requests

      expect(page).to have_css('.ai-panel')
      expect(page).to have_content(/troubleshoot/i)
    end
  end
end
