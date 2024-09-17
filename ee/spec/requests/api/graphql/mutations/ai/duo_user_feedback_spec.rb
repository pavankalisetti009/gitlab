# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'DuoUserFeedback', feature_category: :ai_abstraction_layer do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:agent_version) { create(:ai_agent_version) }
  let(:current_user) { user }
  let(:chat_storage) { Gitlab::Llm::ChatStorage.new(user, agent_version.id) }
  let(:messages) { create_list(:ai_chat_message, 3, user: user, agent_version_id: agent_version.id) }
  let(:ai_message_id) { messages.first.id }
  let(:input) { { agent_version_id: agent_version.to_gid, ai_message_id: ai_message_id } }
  let(:mutation) { graphql_mutation(:duo_user_feedback, input) }
  let(:request_id) { messages.first.request_id }

  subject(:resolve) { post_graphql_mutation(mutation, current_user: current_user) }

  it 'marks the message as having feedback' do
    resolve

    expect(chat_storage.messages.find { |m| m.id == ai_message_id }.extras['has_feedback']).to be(true)
  end

  context 'without a user' do
    let(:current_user) { nil }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'with a non-existing message id' do
    let(:ai_message_id) { 'non-existing' }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'with tracking event data' do
    let(:category) { 'ask_gitlab_chat' }
    let(:action) { 'click_button' }
    let(:label) { 'response_feedback' }
    let(:property) { 'useful,not_relevant' }
    let(:extra) do
      { 'improveWhat' => 'more examples', 'didWhat' => 'provided clarity', 'promptLocation' => 'after_content' }
    end

    let(:event) { { category: category, action: action, label: label, property: property, extra: extra } }
    let(:input) { { agent_version_id: agent_version.to_gid, ai_message_id: ai_message_id, tracking_event: event } }

    it 'tracks the feedback event' do
      resolve

      expect_snowplow_event(
        category: category,
        action: action,
        label: label,
        property: property,
        user: current_user,
        requestId: request_id,
        **extra
      )
    end

    context 'with unexpected `extra` keys' do
      let(:extra) do
        { 'improveWhat' => 'more examples', 'user' => '1' }
      end

      it 'omits the unexpected keys' do
        resolve

        expect_snowplow_event(
          category: category,
          action: action,
          label: label,
          property: property,
          user: current_user,
          requestId: request_id,
          'improveWhat' => 'more examples'
        )
      end
    end
  end
end
