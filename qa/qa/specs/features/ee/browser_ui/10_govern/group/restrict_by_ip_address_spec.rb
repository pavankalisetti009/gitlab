# frozen_string_literal: true

module QA
  RSpec.describe 'Govern' do
    describe 'Group access', :requires_admin, :skip_live_env, product_group: :authentication do
      let!(:current_ip_address) do
        Flow::Login.while_signed_in(as: user) { Runtime::User::Store.admin_user.get_user_ip_address(user.id) }
      end

      let(:user) { Runtime::User::Store.test_user }
      let(:api_client) { user.api_client }
      let(:admin_api_client) { Runtime::User::Store.admin_api_client }

      let(:sandbox_group) { create(:sandbox, api_client: admin_api_client) }
      let(:group) { create(:group, sandbox: sandbox_group, api_client: admin_api_client) }
      let(:project) { create(:project, :with_readme, group: group, api_client: admin_api_client) }

      before do
        project.add_member(user)
        set_ip_address_restriction_to(ip_address)
      end

      context 'when restricted by another ip address' do
        let(:ip_address) { get_next_ip_address(current_ip_address) }

        context 'with UI' do
          it 'denies access', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347923' do
            Flow::Login.sign_in(as: user)

            group.sandbox.visit!(skip_resp_code_check: true)
            expect(page).to have_text('Page not found')
            page.go_back

            group.visit!(skip_resp_code_check: true)
            expect(page).to have_text('Page not found')
            page.go_back
          end
        end

        context 'with API' do
          it 'denies access', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347922' do
            request = create_request("/groups/#{sandbox_group.id}")
            response = Support::API.get request.url
            expect(response.code).to eq(404)

            request = create_request("/groups/#{group.id}")
            response = Support::API.get request.url
            expect(response.code).to eq(404)
          end
        end

        # Note: If you run this test against GDK make sure you've enabled sshd
        # See: https://gitlab.com/gitlab-org/gitlab-qa/blob/master/docs/run_qa_against_gdk.md
        context 'with SSH', :requires_sshd, quarantine: {
          type: :investigating,
          issue: "https://gitlab.com/gitlab-org/gitlab/-/issues/499657",
          only: { job: /gdk-qa-.*/ }
        } do
          let(:key) do
            create(:ssh_key, api_client: api_client, title: "ssh key for allowed ip restricted access #{Time.now.to_f}")
          end

          it 'denies access', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347921' do
            expect { push_a_project_with_ssh_key(key) }.to raise_error(
              QA::Support::Run::CommandError, /fatal: Could not read from remote repository/
            )
          end
        end
      end

      context 'when restricted by user\'s ip address' do
        let(:ip_address) { current_ip_address }

        context 'with UI' do
          it 'allows access', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347926' do
            Flow::Login.sign_in(as: user)

            group.sandbox.visit!
            expect(page).to have_text(group.sandbox.path)

            group.visit!
            expect(page).to have_text(group.path)
          end
        end

        context 'with API' do
          it 'allows access', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347925' do
            request = create_request("/groups/#{sandbox_group.id}")
            response = Support::API.get request.url
            expect(response.code).to eq(200)

            request = create_request("/groups/#{group.id}")
            response = Support::API.get request.url
            expect(response.code).to eq(200)
          end
        end

        # Note: If you run this test against GDK make sure you've enabled sshd
        # See: https://gitlab.com/gitlab-org/gitlab-qa/blob/master/docs/run_qa_against_gdk.md
        context 'with SSH', :requires_sshd, except: { job: 'review-qa-*' }, quarantine: {
          type: :investigating,
          issue: "https://gitlab.com/gitlab-org/gitlab/-/issues/499657",
          only: { job: /gdk-qa-.*/ }
        } do
          let(:key) do
            create(:ssh_key, api_client: api_client, title: "ssh key for allowed ip restricted access #{Time.now.to_f}")
          end

          it 'allows access', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347924' do
            expect { push_a_project_with_ssh_key(key, 2) }.not_to raise_error
          end
        end
      end

      private

      def push_a_project_with_ssh_key(key, attempts = 1)
        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = project
          push.group = sandbox_group
          push.ssh_key = key
          push.branch_name = "new_branch_#{SecureRandom.hex(8)}"
          push.max_attempts = attempts
        end
      end

      def set_ip_address_restriction_to(ip_address)
        sandbox_group.set_ip_restriction_range(ip_address)
      end

      def get_next_ip_address(address)
        current_last_part = address.split(".").pop.to_i

        updated_last_part = current_last_part < 255 ? current_last_part + 1 : 1

        address.split(".")[0...-1].push(updated_last_part).join(".")
      end

      def create_request(api_endpoint)
        Runtime::API::Request.new(api_client, api_endpoint)
      end
    end
  end
end
