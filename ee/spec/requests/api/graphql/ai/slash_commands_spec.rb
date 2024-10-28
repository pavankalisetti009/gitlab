# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Getting Duo Chat slash commands', feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let(:url) { 'https://gitlab.com/some/path' }

  let(:query) do
    <<~GQL
      query($url: String!) {
        aiSlashCommands(url: $url) {
          name
          description
          command
        }
      }
    GQL
  end

  let(:slash_command_data) { graphql_data['aiSlashCommands'] }
  let(:mock_commands) do
    [
      { name: 'help', description: 'Show available commands', command: '/help' },
      { name: 'explain', description: 'Explain the code', command: '/explain' }
    ]
  end

  before do
    allow_next_instance_of(Ai::SlashCommandsService) do |service|
      allow(service).to receive(:available_commands).and_return(mock_commands)
    end
  end

  it 'returns available slash commands' do
    post_graphql(query, current_user: user, variables: { url: url })

    expect(response).to have_gitlab_http_status(:success)
    expect(slash_command_data).to match_array(
      mock_commands.map(&:stringify_keys)
    )
  end

  context 'when the service raises an exception' do
    let(:error_message) { 'An error occurred while fetching slash commands' }

    before do
      allow_next_instance_of(Ai::SlashCommandsService) do |service|
        allow(service).to receive(:available_commands).and_raise(StandardError, error_message)
      end
    end

    it 'returns an error in the response' do
      post_graphql(query, current_user: user, variables: { url: url })

      expect(response).to have_gitlab_http_status(:error)
      expect(graphql_errors).to contain_exactly(
        hash_including('message' => a_string_including(error_message))
      )
    end
  end
end
