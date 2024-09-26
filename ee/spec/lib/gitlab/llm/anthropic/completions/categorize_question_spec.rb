# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Anthropic::Completions::CategorizeQuestion, feature_category: :duo_chat do
  describe '#execute' do
    let(:user) { build(:user) }
    let(:ai_client) { ::Gitlab::Llm::Anthropic::Client.new(nil) }
    let(:response) {  { 'completion' => llm_analysis_response.to_s } }
    let(:llm_analysis_response) do
      {
        detailed_category: "Summarize issue",
        category: 'Summarize something',
        labels: %w[contains_code is_related_to_gitlab],
        language: 'en',
        extra: 'foo'
      }.to_json
    end

    let(:prompt_message) do
      build(:ai_message, :categorize_question, user: user, resource: user, request_id: 'uuid')
    end

    let(:chat_message) { build(:ai_chat_message, content: 'What is the pipeline?') }
    let(:messages) { [chat_message] }

    let(:options) { { question: chat_message.content, message_id: chat_message.id } }

    let(:template_class) { ::Gitlab::Llm::Templates::CategorizeQuestion }
    let(:prompt) { '<prompt>' }

    subject(:categorize_action) do
      described_class.new(prompt_message, template_class, **options).execute
    end

    before do
      allow_next_instance_of(template_class) do |template|
        allow(template).to receive(:to_prompt).and_return(prompt)
      end
      allow_next_instance_of(::Gitlab::Llm::Anthropic::Client) do |ai_client|
        allow(ai_client).to receive(:complete).with(prompt: prompt, max_tokens_to_sample: 200).and_return(response)
      end
      allow_next_instance_of(::Gitlab::Llm::ChatStorage, user) do |storage|
        allow(storage).to receive(:messages_up_to).with(chat_message.id).and_return(messages)
      end
    end

    context 'with valid response' do
      it 'tracks event' do
        expect(categorize_action.errors).to be_empty

        expect_snowplow_event(
          category: described_class.to_s,
          action: 'ai_question_category',
          requestId: 'uuid',
          user: user,
          context: [{
            schema: described_class::SCHEMA_URL,
            data: {
              'detailed_category' => "Summarize issue",
              'category' => 'Summarize something',
              'contains_code' => true,
              'is_related_to_gitlab' => true,
              'number_of_conversations' => 1,
              'number_of_questions_in_conversation' => 1,
              'length_of_questions_in_conversation' => 21,
              'length_of_questions' => 21,
              'first_question_after_reset' => false,
              'time_since_beginning_of_conversation' => 0,
              'language' => 'en'
            }
          }]
        )
      end
    end

    context 'with incomplete response' do
      let(:llm_analysis_response) { { category: 'Summarize something' }.to_json }

      it 'does not track event' do
        expect(categorize_action.errors).to include('Event not tracked')

        expect_no_snowplow_event(
          category: described_class.to_s,
          action: 'ai_question_category',
          requestId: 'uuid',
          user: user,
          context: anything
        )
      end
    end

    context 'with invalid response' do
      let(:llm_analysis_response) { "invalid" }

      it 'does not track event' do
        expect(categorize_action.errors).to include('Event not tracked')

        expect_no_snowplow_event(
          category: described_class.to_s,
          action: 'ai_question_category',
          requestId: 'uuid',
          user: user,
          context: anything
        )
      end
    end
  end
end
