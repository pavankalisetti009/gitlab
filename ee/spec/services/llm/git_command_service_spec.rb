# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::GitCommandService, feature_category: :source_code_management do
  subject { described_class.new(user, user, options) }

  describe '#perform', :saas do
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let(:service_response) do
      ServiceResponse.new(status: :success,
        payload: { predictions:
                   [{ safetyAttributes: [{
                     "blocked" => false,
                     "categories" => [],
                     "scores" => []
                   }],
                      candidates:
                      [{ "content" =>
                       "clever and original AI content",
                         "author" => "1" }] }] })
    end

    let_it_be(:user) { create(:user) }

    let(:options) { { prompt: 'list 10 commit titles' } }

    include_context 'with ai features enabled for group'

    it 'returns an error' do
      expect(subject.execute).to be_error
    end

    context 'when user is a member of ultimate group' do
      before do
        group.add_developer(user)
      end

      it 'responds successfully with a VertexAI ServiceResponse',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/474714' do
        allow(::Gitlab::Llm::VertexAi::Client)
          .to receive_message_chain(:new, :chat)
          .and_return(service_response)

        response = subject.execute

        expect(response).to be_success
        expect(response.payload).to eq(service_response)
      end
    end

    it 'returns an error when messages are too big' do
      stub_const("#{described_class}::INPUT_CONTENT_LIMIT", 4)

      expect(subject.execute).to be_error
    end
  end
end
