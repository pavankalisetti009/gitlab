# frozen_string_literal: true

module QA
  # https://docs.gitlab.com/ee/development/ai_features/duo_chat.html
  RSpec.describe 'Ai-powered', product_group: :duo_chat do
    describe 'Duo Chat' do
      let(:project) { create(:project, name: 'duo-chat-project') }
      let(:token) { Runtime::UserStore.default_api_client.personal_access_token }
      let(:direct_access) { Resource::CodeSuggestions::DirectAccess.fetch_direct_connection_details(token) }
      # Determine whether we are running against dotcom or a self managed cloud connector by checking
      # the base_url of the direct connection endpoint. This lets us determine the expected response.
      # As an orchestrated test we use an ai-gateway with a fake model, so we can assert part of the prompt
      # https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/-/blob/f2fec5c1ae697a7ced9b07e6812a80f3e1f2009a/ai_gateway/models/mock.py#L140
      let(:expected_response) { direct_access[:base_url].include?('gitlab.com') ? 'GitLab' : 'mock' }

      shared_examples 'Duo Chat' do |testcase|
        it 'gets a response back from Duo Chat', testcase: testcase do
          QA::EE::Page::Component::DuoChat.perform do |duo_chat|
            duo_chat.open_duo_chat
            duo_chat.clear_chat_history
            duo_chat.send_duo_chat_prompt('hi')

            Support::Waiter.wait_until(message: 'Wait for Duo Chat response') do
              duo_chat.number_of_messages > 1
            end

            expect(duo_chat.has_response?(expected_response)).to be_truthy,
              "Expected \"#{expected_response}\" within Duo Chat response."
          end
        end
      end

      before do
        Flow::Login.sign_in
        project.visit!
      end

      context 'when initiating Duo Chat' do
        context 'on GitLab.com', :blocking, :external_ai_provider,
          only: { pipeline: %i[staging staging-canary canary production] } do
          it_behaves_like 'Duo Chat', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/441192'
        end

        context 'on Self-managed', :blocking, :orchestrated, :ai_gateway do
          it_behaves_like 'Duo Chat', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/464684'
        end
      end
    end
  end
end
