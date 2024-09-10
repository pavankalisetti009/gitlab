# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::GitCommandService, feature_category: :source_code_management do
  subject { described_class.new(current_user, user, options) }

  describe '#perform', :saas do
    let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:user) { create(:user) }
    let(:current_user) { user }
    let(:options) { { prompt: 'list 10 commit titles' } }

    let(:response) do
      {
        content: [
          {
            text: "This is a response."
          }
        ]
      }
    end

    include_context 'with ai features enabled for group'

    before_all do
      group.add_developer(user)
    end

    before do
      allow_next_instance_of(
        ::Gitlab::Llm::Anthropic::Client,
        current_user,
        unit_primitive: 'glab_ask_git_command'
      ) do |client|
        allow(client)
          .to receive(:messages_complete)
          .and_return(response)
      end
    end

    it 'responds successfully' do
      response = subject.execute

      expect(response).to be_success
      expect(response.payload).to eq({
        predictions: [
          {
            candidates: [
              {
                content: 'This is a response.'
              }
            ]
          }
        ]
      })
    end

    it 'returns an error when messages are too big' do
      stub_const("#{described_class}::INPUT_CONTENT_LIMIT", 4)

      expect(subject.execute).to be_error
    end

    context 'when response is nil' do
      let(:response) { nil }

      it 'responds successfully' do
        response = subject.execute

        expect(response).to be_success
        expect(response.payload).to be_nil
      end
    end

    context 'when user is not a member of ultimate group' do
      let(:current_user) { create(:user) }

      it 'returns an error' do
        expect(subject.execute).to be_error
      end
    end
  end
end
