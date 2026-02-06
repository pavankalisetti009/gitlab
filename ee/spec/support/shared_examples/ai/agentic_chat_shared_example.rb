# frozen_string_literal: true

RSpec.shared_examples 'user can use agentic chat' do
  context 'when using duo agentic chat', :duo_workflow_service do
    let(:model_definitions) do
      {
        'models' => [
          { 'name' => 'Claude Sonnet', 'identifier' => 'claude_sonnet' }
        ],
        'unit_primitives' => [
          {
            'feature_setting' => 'duo_chat',
            'default_model' => 'claude-sonnet',
            'selectable_models' => %w[claude-sonnet],
            'beta_models' => []
          }
        ]
      }
    end

    let(:model_definitions_response) { model_definitions.to_json }

    before do
      stub_feature_flags(duo_ui_next: false)

      stub_config(
        duo_workflow: {
          service_url: "0.0.0.0:#{Tasks::Gitlab::AiGateway::Utils.duo_workflow_service_port}",
          secure: false
        }
      )

      stub_request(:get, "https://cloud.gitlab.com/ai/v1/models%2Fdefinitions")
        .to_return(
          status: 200,
          body: model_definitions_response,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    end

    it 'allows basic UI interactions' do
      visit subject

      # opens AI sidepanel
      expect(page).to have_selector("[data-testid='add-new-agent-toggle']")
      expect(page).to have_selector("[data-testid='ai-chat-toggle']")
      expect(page).to have_selector("[data-testid='ai-history-toggle']")
      expect(page).to have_selector("[data-testid='ai-sessions-toggle']")
      expect(page).not_to have_selector("[data-testid='chat-component']")

      click_button "Active GitLab Duo Chat"

      within_testid('chat-component') do
        expect(page).to have_content('GitLab Duo Agent Platform')
      end

      # Ask a question
      question = 'dummy-question'
      expected_answer = 'mock' # Mock response from DWS via `AIGW_MOCK_MODEL_RESPONSES`
      find_by_testid('chat-prompt-input').fill_in(with: question)
      send_keys :enter

      within_testid('chat-component') do
        expect(page).to have_content(question)
        expect(page).to have_content(expected_answer)
      end

      # Check the chat history
      click_button 'GitLab Duo Chat history'

      within_testid('chat-history') do
        expect(page).to have_content(question)
      end

      # Go back to the active conversation to check the history is loaded
      click_button "Active GitLab Duo Chat"

      within_testid('chat-component') do
        expect(page).to have_content(question)
        expect(page).to have_content(expected_answer)
      end

      # Ask a question again
      question_2 = 'dummy-question-2'
      find_by_testid('chat-prompt-input').fill_in(with: question_2)
      send_keys :enter

      within_testid('chat-component') do
        expect(page).to have_content(question_2)
        expect(page).to have_content(expected_answer)
      end
    end
  end
end
