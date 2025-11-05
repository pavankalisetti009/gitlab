# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat > User navigates Duo Chat history', :js, :saas, :with_current_organization, feature_category: :duo_chat do
  let_it_be(:user) { create(:user, organizations: [current_organization]) }
  let_it_be(:group) { create(:group_with_plan, :public, plan: :ultimate_plan, organization: current_organization) }
  let_it_be(:project) { create(:project, :public, group: group, organization: current_organization) }
  let_it_be(:thread) do
    create(:ai_conversation_thread, user: user, organization: current_organization).tap do |thread|
      create(:ai_conversation_message, content: 'Chat Message', role: :user, thread: thread,
        organization: current_organization)
      create(:ai_conversation_message, content: 'Response', role: :assistant, thread: thread,
        organization: current_organization)
    end
  end

  def open_duo_chat
    find('button.js-tanuki-bot-chat-toggle').click
    wait_for_requests
  end

  def close_popover
    find_by_testid('close-button').click
  end

  before_all do
    group.add_developer(user)
  end

  before do
    allow(user).to receive(:allowed_to_use?).and_return(true)
    allow(user).to receive(:can?).and_call_original

    sign_in(user)

    stub_feature_flags(paneled_view: true)
    user.update!(project_studio_enabled: true)

    visit project_path(project)

    # rubocop:disable RSpec/AvoidConditionalStatements -- temporary Project Studio rollout
    if Users::ProjectStudio.enabled_for_user?(user)
      open_duo_chat
      close_popover
    else
      close_popover
      open_duo_chat
    end
    # rubocop:enable RSpec/AvoidConditionalStatements
  end

  context 'when Chat History button is clicked' do
    it 'opens chat history list' do
      find_by_testid("ai-history-toggle").click
      wait_for_requests

      expect(page).to have_css('[data-testid="chat-threads-thread-box"]')
    end
  end
end
