# frozen_string_literal: true

module QA
  # Do not run on production as this creates error logs
  RSpec.describe 'Secure', product_group: :secret_detection, except: { pipeline: [:canary, :production] } do
    describe 'Secret Push Protection' do
      let!(:project) do
        create(:project, :with_readme, name: 'secret-push-project', description: 'Secret Push Protection Project')
      end

      # In reverse so that the test itself does not flag up a secret detection issue
      let(:reverse_token_prefix) { 'taplg' }
      let(:test_token) { '-JUST20LETTERSANDNUMB' }

      it 'blocks commit when enabled when token is detected',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/468475' do
        Flow::Login.sign_in_unless_signed_in

        enable_secret_protection_for_self_managed unless Runtime::Env.running_on_dot_com?

        project.visit!
        Page::Project::Menu.perform(&:go_to_security_configuration)

        Page::Project::Secure::ConfigurationForm.perform do |config_form|
          expect(config_form).to have_false_secret_detection_status

          config_form.enable_secret_detection

          expect(config_form).to have_true_secret_detection_status
        end

        Git::Repository.perform do |repository|
          repository.uri = project.repository_http_location.uri
          repository.use_default_credentials
          repository.default_branch = project.default_branch
          repository.clone
          repository.configure_identity('GitLab QA', 'root@gitlab.com')
          repository.commit_file("new-file", reverse_token_prefix.reverse + test_token, "Add token file")
          result = repository.push_changes(raise_on_failure: false)

          expect(result).to match(expected_error_pattern)
        end
      end

      private

      def enable_secret_protection_for_self_managed
        Page::Main::Menu.perform(&:go_to_admin_area)
        Page::Admin::Menu.perform(&:go_to_security_and_compliance_settings)
        EE::Page::Admin::Settings::Securityandcompliance.perform(&:click_secret_protection_setting_checkbox)
      end

      def error_messages
        {
          blocked: 'PUSH BLOCKED: Secrets detected in code changes',
          found: 'Secret push protection found the following secrets in commit',
          token: 'GitLab [Pp]ersonal [Aa]ccess [Tt]oken',
          resolution: 'To push your changes you must remove the identified secrets.'
        }
      end

      def expected_error_pattern
        messages = error_messages
        %r{.*#{messages[:blocked]}[\s\S]*#{messages[:found]}[\s\S]*#{messages[:token]}[\s\S]*#{messages[:resolution]}}
      end
    end
  end
end
