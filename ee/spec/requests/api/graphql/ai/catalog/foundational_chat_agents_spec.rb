# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting AI foundational chat agents', feature_category: :workflow_catalog do
  include GraphqlHelpers

  let(:nodes) { graphql_data_at(:ai_foundational_chat_agents, :nodes) }

  let(:query) do
    "{ #{query_nodes('AiFoundationalChatAgents')} }"
  end

  it 'returns all foundational chat agents sorted by id' do
    post_graphql(query, current_user: nil)

    expect(response).to have_gitlab_http_status(:success)
    expect(nodes).to have_attributes(size: ::Ai::FoundationalChatAgent.count)
    expect(nodes.sort_by { |node| node['id'] }).to eq(nodes)

    first_node = nodes.first

    expect(first_node["id"]).to eq("gid://gitlab/Ai::FoundationalChatAgent/chat")
    expect(first_node["name"]).to eq("GitLab Duo Agent")
    expect(first_node["reference"]).to eq("chat")
    expect(first_node["referenceWithVersion"]).to eq("chat")
    expect(first_node["version"]).to eq("")
  end
end
