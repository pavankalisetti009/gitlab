# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/_tanuki_bot_chat', feature_category: :duo_chat do
  let(:current_user) { build_stubbed(:user) }

  before do
    allow(view).to receive(:current_user).and_return(current_user)
    allow(::Gitlab::Llm::TanukiBot).to receive_messages(
      enabled_for?: true,
      resource_id: 'test_resource_id',
      project_id: 'test_project_id'
    )
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
