# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/_duo_chat_panel', feature_category: :duo_chat do
  let(:user) { build_stubbed(:user) }
  let(:group) { build(:group) }

  before do
    allow(view).to receive_messages(
      current_user: user,
      project_studio_enabled?: true
    )
    assign(:group, group)

    allow(::Ai::AmazonQ).to receive(:enabled?).and_return(amazon_q_enabled)
    allow(::Gitlab::Llm::TanukiBot)
      .to receive(:show_breadcrumbs_entry_point?)
      .with(user: user)
      .and_return(duo_enabled)
  end

  context 'when duo is enabled' do
    let(:amazon_q_enabled) { false }
    let(:duo_enabled) { true }

    it 'renders the ai panel' do
      render

      expect(rendered).to have_css('#duo-chat-panel')
    end
  end

  context 'when amazon_q is enabled' do
    let(:amazon_q_enabled) { true }
    let(:duo_enabled) { true }

    it 'does not render the ai panel' do
      render

      expect(rendered).not_to have_css('#duo-chat-panel')
    end
  end

  context 'when duo is disabled' do
    let(:amazon_q_enabled) { false }
    let(:duo_enabled) { false }

    it 'does not render the ai panel' do
      render

      expect(rendered).not_to have_css('#duo-chat-panel')
    end
  end
end
