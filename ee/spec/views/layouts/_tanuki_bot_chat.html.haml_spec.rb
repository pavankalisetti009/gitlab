# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/_tanuki_bot_chat', feature_category: :duo_chat do
  let(:current_user) { build_stubbed(:user) }
  let(:project) { build_stubbed(:project) }
  let(:duo_scope_hash) { { project: project } }

  before do
    allow(view).to receive_messages(current_user: current_user, project_studio_enabled?: false)
    allow(current_user).to receive(:can?).and_return(true)
    allow(::Gitlab::Llm::TanukiBot).to receive_messages(
      duo_scope_hash: duo_scope_hash,
      enabled_for?: true,
      resource_id: 'test_resource_id',
      project_id: project.to_global_id,
      root_namespace_id: 'test_root_namespace_id',
      credits_available?: true
    )
    assign(:project, project)
  end

  it 'renders duo agentic chat app with attributes' do
    render

    expected_metadata = { extended_logging: true, is_team_member: nil }.to_json

    expect(rendered).to have_css("#js-duo-agentic-chat-app[data-project-id='#{project.to_global_id}']")
    expect(rendered).to have_css("#js-duo-agentic-chat-app[data-resource-id='test_resource_id']")
    expect(rendered).to have_css("#js-duo-agentic-chat-app[data-metadata='#{expected_metadata}']")
    expect(rendered).to have_css("#js-duo-agentic-chat-app[data-root-namespace-id='test_root_namespace_id']")
    expect(rendered).not_to have_css("#js-duo-agentic-chat-app[data-namespace-id]")
  end

  it 'renders credits_available attribute as true when credits are available' do
    allow(::Gitlab::Llm::TanukiBot).to receive(:credits_available?).and_return(true)

    render

    expect(rendered).to have_css("#js-duo-agentic-chat-app[data-credits-available='true']")
  end

  it 'renders credits_available attribute as false when credits are unavailable' do
    allow(::Gitlab::Llm::TanukiBot).to receive(:credits_available?).and_return(false)

    render

    expect(rendered).to have_css("#js-duo-agentic-chat-app[data-credits-available='false']")
  end

  context 'when the page is in group scope' do
    let(:group) { build_stubbed(:group) }
    let(:duo_scope_hash) { { namespace: group } }

    it 'renders duo agentic chat app with only group scope' do
      assign(:group, group)

      render

      expect(rendered).to have_css("#js-duo-agentic-chat-app[data-namespace-id='#{group.to_global_id}']")
      expect(rendered).not_to have_css("#js-duo-agentic-chat-app[data-project-id]")
    end
  end

  context 'when the page has no scope' do
    let(:duo_scope_hash) { {} }

    it 'renders duo agentic chat app without scope attributes' do
      render

      expect(rendered).not_to have_css("#js-duo-agentic-chat-app[data-project-id]")
      expect(rendered).not_to have_css("#js-duo-agentic-chat-app[data-namespace-id]")
    end
  end
end
