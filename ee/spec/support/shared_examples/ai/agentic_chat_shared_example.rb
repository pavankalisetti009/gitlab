# frozen_string_literal: true

RSpec.shared_examples 'user can use agentic chat' do
  context 'when using duo agentic chat', :duo_workflow_service do
    let(:model_definitions) do
      {
        'models' => [
          { 'name' => 'Claude Sonnet', 'identifier' => 'claude_sonnet_4_5_20250929' },
          { 'name' => 'Claude Haiku', 'identifier' => 'claude_haiku_4_5_20251001' }
        ],
        'unit_primitives' => [
          {
            'feature_setting' => 'duo_agent_platform_agentic_chat',
            'default_model' => 'claude_sonnet_4_5_20250929',
            'selectable_models' => %w[claude_sonnet_4_5_20250929 claude_haiku_4_5_20251001],
            'beta_models' => []
          }
        ]
      }
    end

    let(:model_definitions_response) { model_definitions.to_json }

    before do
      stub_feature_flags(duo_ui_next: false, use_generic_gitlab_api_tools: false)

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

      # Ask a question - Mock responses are generated via `AIGW_USE_AGENTIC_MOCK`
      question = 'dummy-question'
      expected_answer = 'mock'
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

    it 'allows user to ask about entity' do
      skip unless defined?(container) && defined?(entity)

      visit subject

      # opens AI sidepanel
      click_button "Active GitLab Duo Chat"

      within_testid('chat-component') do
        expect(page).to have_content('GitLab Duo Agent Platform')
      end

      # Ask a question - Mock responses are generated via `AIGW_USE_AGENTIC_MOCK`
      tool_call = { name: "", args: {} }
      expected_tool_message = "Read"

      if entity.is_a?(::Issue) || entity.is_a?(::Epic)
        tool_call[:name] = "get_work_item"
        tool_call[:args][:work_item_iid] = entity.iid
        expected_tool_message += " work item ##{entity.iid}"
      elsif entity.is_a?(::MergeRequest)
        tool_call[:name] = "get_merge_request"
        tool_call[:args][:merge_request_iid] = entity.iid
        expected_tool_message += " merge request !#{entity.iid}"
      else
        raise NotImplementedError
      end

      if container.is_a?(::Project)
        tool_call[:args][:project_id] = container.id
        expected_tool_message += " in project #{container.id}"
      elsif container.is_a?(::Group)
        tool_call[:args][:group_id] = container.id
        expected_tool_message += " in group #{container.id}"
      else
        raise NotImplementedError
      end

      tool_calls = [tool_call]
      agent_msg_1 = "<response>I should search the entity<tool_calls>#{tool_calls.to_json}</tool_calls></response>"
      agent_msg_2 = "<response>Found the entity</response>"
      user_msg = "<responses>#{agent_msg_1}#{agent_msg_2}</responses>"
      find_by_testid('chat-prompt-input').fill_in(with: user_msg)
      send_keys :enter

      # Check agent response
      within_testid('chat-component') do
        expect(page).to have_content('I should search the entity')
        expect(page).to have_content(expected_tool_message)
        expect(page).to have_content('Found the entity')
      end
    end

    it 'allows user to create a new entity' do
      skip unless defined?(container) && defined?(entity)

      visit subject

      # opens AI sidepanel
      click_button "Active GitLab Duo Chat"

      within_testid('chat-component') do
        expect(page).to have_content('GitLab Duo Agent Platform')
      end

      # Ask a task. Mock responses are generated via `AIGW_USE_AGENTIC_MOCK`
      tool_call = { name: "", args: {} }
      expected_tool_message = ""
      assert_db = nil

      if entity.is_a?(::Issue) && container.is_a?(::Project)
        tool_call[:name] = "create_work_item"
        tool_call[:args][:title] = "New issue"
        tool_call[:args][:type_name] = "Issue"
        tool_call[:args][:project_id] = container.id
        expected_tool_message = "Create work item"

        assert_db = -> do
          expect(::Issue.exists?(title: "New issue", project_id: container.id)).to be(true)
        end
      elsif entity.is_a?(::Epic) && container.is_a?(::Group)
        tool_call[:name] = "create_work_item"
        tool_call[:args][:title] = "New epic"
        tool_call[:args][:type_name] = "Epic"
        tool_call[:args][:group_id] = container.id
        expected_tool_message = "Create work item"

        assert_db = -> do
          expect(::Epic.exists?(title: "New epic", group_id: container.id)).to be(true)
        end
      elsif entity.is_a?(::MergeRequest) && container.is_a?(::Project)
        entity.destroy! # Destroying the MR at first as a duplicate MR can't be created.

        tool_call[:name] = "create_merge_request"
        tool_call[:args][:title] = "New feature"
        tool_call[:args][:project_id] = container.id
        tool_call[:args][:source_branch] = entity.source_branch
        tool_call[:args][:target_branch] = entity.target_branch
        expected_tool_message = "Create merge request"

        assert_db = -> do
          expect(::MergeRequest.exists?(title: "New feature", project_id: container.id)).to be(true)
        end
      else
        raise NotImplementedError
      end

      tool_calls = [tool_call]
      agent_msg_1 = "<response>I should create a new entity<tool_calls>#{tool_calls.to_json}</tool_calls></response>"
      agent_msg_2 = "<response>Entity created</response>"
      user_msg = "<responses>#{agent_msg_1}#{agent_msg_2}</responses>"
      find_by_testid('chat-prompt-input').fill_in(with: user_msg)
      send_keys :enter

      # Approve the tool use
      within_testid('chat-component') do
        click_button "Approve"
      end

      # Check agent response
      within_testid('chat-component') do
        expect(page).to have_content('I should create a new entity')
        expect(page).to have_content(expected_tool_message)
        expect(page).to have_content('Approved')
        expect(page).to have_content('Entity created')
      end

      # Check internal DB record that the entity was persisted.
      assert_db&.call
    end

    it 'allows user to select a custom agent' do
      visit subject

      # Show the list of agents
      click_button "Add new chat"

      find('.gl-new-dropdown-item', text: 'Data Analyst').click

      # Select the other agent
      within_testid('chat-subheader') do
        expect(page).to have_content('Data Analyst')
      end

      # Ask a question - Mock responses are generated via `AIGW_USE_AGENTIC_MOCK`
      agent_msg = "Based on my analysis..."
      user_msg = "<response>#{agent_msg}</response>"
      find_by_testid('chat-prompt-input').fill_in(with: user_msg)
      send_keys :enter

      # Check agent response
      within_testid('chat-history') do
        expect(page).to have_css('.duo-chat-message', count: 2)
        expect(page).to have_css('.duo-chat-message:nth-child(2)', text: agent_msg)
      end

      created_workflow = ::Ai::DuoWorkflows::Workflow.last
      expect(created_workflow.workflow_definition).to eq('analytics_agent/v1')
    end

    it 'allows user to select a model' do
      visit subject

      # Shows the list of agents
      click_button "Add new chat"

      find('.gl-new-dropdown-item', text: 'GitLab Duo').click

      within_testid('chat-subheader') do
        expect(page).to have_content('GitLab Duo')
      end

      # Show the list of models
      within_testid('chat-component') do
        click_button "Claude Sonnet - Default"
      end

      # Select the other model
      within_testid('model-dropdown-container') do
        find('.gl-new-dropdown-item', text: 'Claude Haiku').click
      end

      # Ask a question - Mock responses are generated via `AIGW_USE_AGENTIC_MOCK`
      agent_msg = "I am Haiku"
      user_msg = "<response>#{agent_msg}</response>"
      find_by_testid('chat-prompt-input').fill_in(with: user_msg)
      send_keys :enter

      # Check agent response
      within_testid('chat-history') do
        expect(page).to have_css('.duo-chat-message', count: 2)
        expect(page).to have_css('.duo-chat-message:nth-child(2)', text: agent_msg)
      end
    end
  end
end
