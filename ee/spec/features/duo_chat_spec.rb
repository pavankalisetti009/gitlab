# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat', :js, :saas, :clean_gitlab_redis_cache, :with_cloud_connector, feature_category: :duo_chat do
  let_it_be(:user) { create(:user, :with_namespace) }

  before do
    group.add_developer(user)
    create(:callout, user: user, feature_name: :duo_chat_callout)
  end

  context 'when group does not have an AI features license' do
    let_it_be_with_reload(:group) { create(:group_with_plan) }

    before do
      sign_in(user)
      visit group_path(group)
    end

    it 'does not show the button to open chat' do
      expect(page).not_to have_button('Active GitLab Duo Chat')
    end
  end

  context 'when group has an AI features license', :sidekiq_inline do
    using RSpec::Parameterized::TableSyntax

    include_context 'with duo features enabled and ai chat available for group on SaaS'

    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :premium_plan) }
    let_it_be(:project) { create(:project, :repository, group: group) }

    let(:question) { 'Who are you?' }
    let(:answer) { "Hello! I'm GitLab Duo Chat" }
    let(:chat_response) do
      create(:final_answer_multi_chunk, chunks: ["Hello", "!", " I", "'m Git", "Lab Duo", " Chat,"])
    end

    let!(:cloud_connector_key) { create(:cloud_connector_keys) }

    before do
      allow_next_instance_of(::Ai::UsageQuotaService) do |service|
        allow(service).to receive(:execute).and_return(ServiceResponse.success)
      end

      stub_saas_features(duo_chat_categorize_question: false)

      stub_request(:post, "#{Gitlab::AiGateway.url}/v2/chat/agent")
        .to_return(status: 200, body: chat_response)

      sign_in(user)

      visit group_path(group)
    end

    where(:disabled_reason, :visit_path, :expected_button_state) do
      'project' | :visit_project | :disabled
      'project' | :visit_root | :disabled
      'group' | :visit_group | :disabled
      'group' | :visit_root | :disabled
      nil | :visit_group | :enabled
      nil | :visit_project | :enabled
      nil | :visit_root | :enabled
    end

    with_them do
      it 'shows the correct button state and tooltip' do
        allow(::Gitlab::Llm::TanukiBot).to receive(:chat_disabled_reason).and_return(disabled_reason)

        case visit_path
        when :visit_group
          visit group_path(group)
        when :visit_project
          visit project_path(project)
        when :visit_root
          visit root_path
        end

        case expected_button_state
        when :disabled
          duo_chat_button = find_by_testid("ai-chat-toggle")
          expect(duo_chat_button['aria-disabled']).to eq('true')
        when :enabled
          expect(page).to have_button('Active GitLab Duo Chat')
        end
      end
    end

    it 'returns response after asking a question' do
      open_chat
      chat_request(question)

      within_testid('chat-component') do
        expect(page).to have_content(question)
        expect(page).to have_content(answer)
      end
    end

    it 'stores the chat history' do
      open_chat
      chat_request(question)

      page.refresh
      open_history

      within_testid('chat-history') do
        expect(page).to have_content(question)
      end
    end
  end

  def open_chat
    click_button "Active GitLab Duo Chat"
  end

  def open_history
    click_button "GitLab Duo Chat history"
  end

  def chat_request(question)
    expect(page).to have_selector("[data-testid='chat-prompt-form']")
    expect(page).to have_selector("[data-testid='chat-prompt-input']")

    find_by_testid('chat-prompt-input').fill_in(with: question)
    send_keys :enter
    wait_for_requests
  end
end
