# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/nav/_ask_duo_button', feature_category: :duo_chat do
  let(:user) { build_stubbed(:user) }
  let(:group) { build_stubbed(:group) }
  let(:project) { build_stubbed(:project, namespace: group) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:group, group)
    assign(:project, project)
  end

  context 'when Duo Chat is enabled' do
    before do
      allow(::Gitlab::Llm::TanukiBot).to receive_messages(
        show_breadcrumbs_entry_point?: true,
        chat_disabled_reason: nil
      )
    end

    it 'renders the Duo Chat button with correct aria-label' do
      render

      expect(rendered).to have_selector('.js-tanuki-bot-chat-toggle[aria-label="GitLab Duo Chat"]')
    end
  end

  context 'when Amazon Q is enabled' do
    before do
      allow(::Ai::AmazonQ).to receive(:enabled?).and_return(true)
      allow(::Gitlab::Llm::TanukiBot).to receive_messages(
        show_breadcrumbs_entry_point?: true,
        chat_disabled_reason: nil
      )
    end

    it 'renders the Duo Chat button with Amazon Q aria-label' do
      render

      expect(rendered).to have_selector('.js-tanuki-bot-chat-toggle[aria-label="GitLab Duo with Amazon Q"]')
    end
  end
end
