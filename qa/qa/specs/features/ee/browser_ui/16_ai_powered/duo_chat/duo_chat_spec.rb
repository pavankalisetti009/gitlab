# frozen_string_literal: true

module QA
  # https://docs.gitlab.com/ee/development/ai_features/duo_chat.html
  RSpec.describe 'Ai-powered', product_group: :duo_chat do
    describe 'Duo Chat' do
      let(:user) { Runtime::User::Store.test_user }
      let(:api_client) { Runtime::User::Store.default_api_client }
      let(:token) { api_client.personal_access_token }
      let(:project) { create(:project, name: 'duo-chat-project', api_client: api_client) }
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

            begin
              response_with_failover = expected_response
            rescue RuntimeError
              # If direct connection request fails, assume we are on SaaS
              response_with_failover = 'GitLab'
            end

            expect(duo_chat.has_response?(response_with_failover)).to be_truthy,
              "Expected \"#{response_with_failover}\" within Duo Chat response."
          end
        end
      end

      before do
        Flow::Login.sign_in(as: user)
        project.visit!
      end

      context 'when initiating Duo Chat' do
        context 'on GitLab.com', :external_ai_provider,
          only: { pipeline: %i[staging staging-canary canary production] } do
          it_behaves_like 'Duo Chat', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/441192'
        end

        context 'on Self-managed', :orchestrated, :ai_gateway do
          let(:api_client) { Runtime::User::Store.admin_api_client }
          let(:user) { Runtime::User::Store.admin_user }

          it_behaves_like 'Duo Chat', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/464684'
        end
      end
    end
  end
end
