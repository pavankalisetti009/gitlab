# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/_tanuki_bot_chat', feature_category: :duo_chat do
  let(:current_user) { build_stubbed(:user) }
  let(:project) { build_stubbed(:project) }

  before do
    allow(view).to receive(:current_user).and_return(current_user)
    allow(current_user).to receive(:can?).and_return(true)
    allow(::Gitlab::Llm::TanukiBot).to receive_messages(
      enabled_for?: true,
      resource_id: 'test_resource_id',
      project_id: project.to_global_id,
      root_namespace_id: 'test_root_namespace_id'
    )
    assign(:project, project)
  end

  it 'renders duo agentic chat app with attributes' do
    render

    expected_metadata = { extended_logging: true, is_team_member: nil }.to_json

    expect(rendered).to have_css("#js-duo-agentic-chat-app[data-project-id='#{project.to_global_id}']")
    expect(rendered).to have_css("#js-duo-agentic-chat-app[data-resource-id='test_resource_id']")
    expect(rendered).to have_css("#js-duo-agentic-chat-app[data-metadata='#{expected_metadata}']")
  end

  context 'when the page is in group scope' do
    let(:group) { build_stubbed(:group) }

    it 'renders duo agentic chat app with attributes' do
      assign(:group, group)

      render

      expect(rendered).to have_css("#js-duo-agentic-chat-app[data-namespace-id='#{group.to_global_id}']")
    end
  end

  it 'includes the root_namespace_id in the data attributes' do
    render

    expect(rendered).to have_css("#js-tanuki-bot-chat-app[data-root-namespace-id='test_root_namespace_id']")
  end

  context 'when AmazonQ is enabled' do
    before do
      allow(::Ai::AmazonQ).to receive(:enabled?).and_return(true)
    end

    it 'sets the correct chat title' do
      render

      expect(rendered).to have_css("#js-tanuki-bot-chat-app[data-chat-title='GitLab Duo Chat with Amazon Q']")
    end
  end

  context 'when AmazonQ is not enabled' do
    before do
      allow(::Ai::AmazonQ).to receive(:enabled?).and_return(false)
    end

    it 'sets the correct chat title' do
      render

      expect(rendered).to have_css("#js-tanuki-bot-chat-app[data-chat-title='GitLab Duo Chat']")
    end
  end
end
