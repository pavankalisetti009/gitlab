# frozen_string_literal: true

module QA
  # https://docs.gitlab.com/ee/development/ai_features/duo_chat.html
  RSpec.describe 'Create', product_group: :duo_chat do
    describe 'Duo Chat in Web IDE' do
      include_context 'Web IDE test prep'
      shared_examples 'Duo Chat' do |testcase|
        it 'gets a response back from Duo Chat', testcase: testcase do
          Page::Project::WebIDE::VSCode.perform do |ide|
            ide.open_duo_chat
            ide.within_vscode_duo_chat do
              QA::EE::Page::Component::DuoChat.perform do |duo_chat|
                duo_chat.clear_chat_history
                expect(duo_chat).to be_empty_state
                duo_chat.send_duo_chat_prompt('hi')

                begin
                  response_with_failover = expected_response
                rescue RuntimeError
                  # If direct connection request fails, assume we are on SaaS
                  response_with_failover = 'GitLab'
                end

                expect(duo_chat).to have_response(response_with_failover),
                  "Expected '#{expected_response}' within Duo Chat response."
              end
            end
          end
        end
      end

      let(:project) { create(:project, :with_readme, name: 'webide-duo-chat-project') }
      let(:token) { Runtime::User::Store.default_api_client.personal_access_token }
      let(:direct_access) { Resource::CodeSuggestions::DirectAccess.fetch_direct_connection_details(token) }
      # Determine whether we are running against dotcom or a self managed cloud connector by checking
      # the base_url of the direct connection endpoint. This lets us determine the expected response.
      # As an orchestrated test we use an ai-gateway with a fake model, so we can assert part of the prompt
      # https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/-/blob/f2fec5c1ae697a7ced9b07e6812a80f3e1f2009a/ai_gateway/models/mock.py#L140
      let(:expected_response) { direct_access[:base_url].include?('gitlab.com') ? 'GitLab' : 'mock' }

      before do
        load_web_ide
      end

      context 'on GitLab.com', :external_ai_provider,
        only: { pipeline: %i[staging staging-canary canary production] } do
        it_behaves_like 'Duo Chat', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/443762'
      end

      context 'on Self-managed', :orchestrated, :ai_gateway, quarantine: {
        type: :investigating,
        issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/494690'
      } do
        it_behaves_like 'Duo Chat', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/468854'
      end
    end
  end
end
