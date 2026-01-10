# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    only: { job: 'gdk-instance-secrets-manager' },
    feature_category: :secrets_management
  ) do
    include_context 'secrets manager base'
    describe 'Project Secret' do
      def reporter
        @reporter ||= create(:user)
      end

      def user_in_a_group
        @user_in_a_group ||= create(:user)
      end

      def group
        @group ||= create(:group)
      end

      def secret_name
        @secret_name ||= "reading_secret"
      end

      before(:context) do
        project.add_member(reporter, Resource::Members::AccessLevel::REPORTER)
        project.invite_group(group, Resource::Members::AccessLevel::DEVELOPER)
        group.add_member(user_in_a_group)

        Page::Main::Menu.perform(&:sign_out)
        Flow::Login.sign_in(as: owner)
        project.visit!

        Page::Project::Menu.perform(&:go_to_general_settings)
        Page::Project::Settings::Main.perform do |settings|
          settings.expand_visibility_project_features_permissions do |permissions_page|
            permissions_page.add_group_permission(group_path: group.full_path, scopes: %w[read])
          end
        end

        Page::Project::Menu.perform(&:go_to_secrets_manager)
        EE::Page::Project::Secure::SecretsManager.perform do |secrets_page|
          secrets_page.click_new_secret
          secrets_page.create_secret(
            name: secret_name,
            value: 'testvalue',
            description: "Test reading a secret",
            environment: '*',
            branch: 'main'
          )
        end
      end

      context 'when reading a project secret' do
        it 'successfully reads a secret when a User from group has read permissions',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/581639' do
          Page::Main::Menu.perform(&:sign_out)
          Flow::Login.sign_in(as: user_in_a_group)
          project.visit!

          Page::Project::Menu.perform(&:go_to_secrets_manager)
          EE::Page::Project::Secure::SecretsManager.perform do |secrets_page|
            expect(secrets_page).to have_secret_in_table(secret_name)
          end
        end

        it 'fails to read a secret when Reporter has no read permissions',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/581640' do
          Page::Main::Menu.perform(&:sign_out)
          Flow::Login.sign_in(as: reporter)
          project.visit!

          Page::Project::Menu.perform(&:go_to_secrets_manager)
          EE::Page::Project::Secure::SecretsManager.perform do |secrets_page|
            expect(secrets_page).to have_permissions_error
          end
        end
      end
    end
  end
end
