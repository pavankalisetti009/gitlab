# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::GitCommandService, feature_category: :source_code_management do
  subject { described_class.new(user, user, options) }

  describe '#perform', :saas do
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:user) { create(:user) }

    let(:options) { { prompt: 'list 10 commit titles' } }

    include_context 'with ai features enabled for group'

    it 'returns an error' do
      expect(subject.execute).to be_error
    end

    context 'when the move_git_service_to_ai_gateway feature flag is enabled' do
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

      context 'when user is a member of ultimate group' do
        before do
          allow(user).to receive(:can?).with(:access_glab_ask_git_command).and_return(true)
        end

        it 'responds successfully with a VertexAI ServiceResponse' do
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

    context 'when the move_git_service_to_ai_gateway feature flag is disabled' do
      context 'when user is a member of ultimate group' do
        before do
          stub_licensed_features(glab_ask_git_command: true)
          stub_feature_flags(move_git_service_to_ai_gateway: false)

          group.add_developer(user)
        end

        it 'responds successfully with VertexAI formatted params' do
          stub_ee_application_setting(vertex_ai_host: 'host', vertex_ai_project: 'c')

          allow_next_instance_of(::Gitlab::Llm::VertexAi::Configuration) do |instance|
            allow(instance).to receive(:access_token).and_return('access token')
          end

          response = subject.execute

          expect(response).to be_success
          expect(response.payload).to include({
            headers: {
              "Accept" => "application/json",
              "Authorization" => "Bearer access token",
              "Content-Type" => "application/json",
              "Host" => be_an(String),
              'X-Gitlab-Authentication-Type' => 'oidc',
              'X-Gitlab-Global-User-Id' => be_an(String),
              'X-Gitlab-Host-Name' => be_an(String),
              'X-Gitlab-Instance-Id' => be_an(String),
              'X-Gitlab-Rails-Send-Start' => be_an(String),
              'X-Gitlab-Realm' => be_an(String),
              'X-Gitlab-Unit-Primitive' => 'glab_ask_git_command',
              'X-Gitlab-Version' => be_an(String),
              'X-Request-ID' => be_an(String)
            }
          })

          expect(response.payload[:url]).to include(
            "/v1/proxy/vertex-ai/v1/projects/PROJECT/locations/LOCATION/publishers/google/models/codechat-bison:predict"
          )

          expect(::Gitlab::Json.parse(response.payload[:body])['instances'][0]['messages']).to eq([{
            'author' => 'content',
            'content' => "Provide the appropriate git commands for: list 10 commit titles.\n\n" \
            "Respond with git commands wrapped in separate ``` blocks.\n" \
            "Provide explanation for each command in a separate block.\n\n##\n" \
            "Example:\n\n```\ngit log -10\n```\n\n" \
            "This command will list the last 10 commits in the current branch.\n"
          }])
        end

        it 'returns an error when messages are too big' do
          stub_const("#{described_class}::INPUT_CONTENT_LIMIT", 4)

          expect(subject.execute).to be_error
        end
      end
    end
  end
end
