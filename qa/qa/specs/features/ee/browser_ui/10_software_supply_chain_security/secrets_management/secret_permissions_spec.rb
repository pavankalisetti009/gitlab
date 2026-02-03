# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    only: { job: 'gdk-instance-secrets-manager' },
    feature_category: :secrets_management
  ) do
    include_context 'secrets manager with all users'
    describe 'Update and Delete on secret permissions' do
      context 'when owner enables secrets manager' do
        it 'automatically creates owner permissions and displays them in roles tab',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/579566',
          quarantine: { issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/29022',
                        type: 'flaky' } do
          Page::Main::Menu.perform(&:sign_out)
          Flow::Login.sign_in(as: owner)
          project.visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_visibility_project_features_permissions do |permissions_page|
              expect(permissions_page).to have_secrets_manager_permissions_section
              expect(permissions_page).to have_owner_permissions_in_roles_tab

              QA::Runtime::Logger.info("✓ Owner permissions automatically created with all scopes")
            end
          end
        end
      end

      context 'when testing access control for secret permissions management' do
        it 'allows only project owner to access secret permissions management',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/579568',
          quarantine: { issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/29022',
                        type: 'flaky' } do
          # Test that maintainer access secret permissions management, but not edit them.
          Page::Main::Menu.perform(&:sign_out)
          Flow::Login.sign_in(as: maintainer)
          project.visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_visibility_project_features_permissions do |permissions_page|
              # Maintainer should see secret permissions management section, but not able to edit them
              expect(permissions_page).to have_secrets_manager_permissions_section
              expect(permissions_page).not_to have_add_permission_button
            end
          end

          # Test that reporter cannot access secret permissions management
          Page::Main::Menu.perform(&:sign_out)
          Flow::Login.sign_in(as: reporter)
          project.visit!

          expect(page).not_to have_css('[data-testid="project-settings-sidebar"]')
          visit("#{project.web_url}/edit#js-shared-permissions")
          expect(page).to have_text('404: Page not found')
        end
      end

      context 'when a non-owner access the secret permissions' do
        it 'cannot access secret permissions page',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/579569',
          quarantine: { issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/29022',
                        type: 'flaky' } do
          Page::Main::Menu.perform(&:sign_out)
          Flow::Login.sign_in(as: non_project_owner)
          project.visit!

          expect(page).not_to have_css('[data-testid="project-settings-sidebar"]')
          visit("#{project.web_url}/edit#js-shared-permissions")
          expect(page).to have_text('404: Page not found')
        end
      end

      context 'when an owner creates permissions for a project-group' do
        # rubocop:disable RSpec/InstanceVariable -- before(:context) requires instance variable to share state across examples
        def new_group
          @new_group
        end

        before(:context) do
          @new_group = create(:group)
          new_group.add_member(owner, Resource::Members::AccessLevel::OWNER)

          Support::Waiter.wait_until(max_duration: 10, sleep_interval: 1) do
            new_group.reload!
            new_group.find_member(owner.username).present?
          end

          Support::API.post(
            Runtime::API::Request.new(Runtime::User::Store.admin_api_client, "/projects/#{project.id}/share").url,
            { group_id: new_group.id, group_access: 30 } # 30 = Developer
          )
          Support::Waiter.wait_until(max_duration: 10, sleep_interval: 1) do
            project.reload!
          end
        end
        # rubocop:enable RSpec/InstanceVariable

        it 'successfully creates permissions',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/579570',
          quarantine: { issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/29022',
                        type: 'flaky' } do
          Page::Main::Menu.perform(&:sign_out)
          Flow::Login.sign_in(as: owner)
          project.visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_visibility_project_features_permissions do |permissions_page|
              scopes = %w[read write delete]
              permissions_page.add_group_permission(group_path: new_group.full_path, scopes: scopes)
              expect(permissions_page).to have_group_permission(group_name: new_group.name, scopes: scopes)
            end
          end
        end
      end

      context 'when owner creates permission for non-project user' do
        it 'fails to create the secret permission',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/579706',
          quarantine: { issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/29022',
                        type: 'flaky' } do
          Page::Main::Menu.perform(&:sign_out)
          Flow::Login.sign_in(as: owner)
          project.visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_visibility_project_features_permissions do |permissions_page|
              scopes = %w[read]
              expect do
                permissions_page.add_user_permission(username: non_project_user.username, scopes: scopes)
              end.to raise_error
            end
          end
        end
      end

      context 'when owner creates permission for developer-role without read permission' do
        it 'fails to create the secret permission',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/579708',
          quarantine: { issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/29022',
                        type: 'flaky' } do
          Page::Main::Menu.perform(&:sign_out)
          Flow::Login.sign_in(as: owner)
          project.visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_visibility_project_features_permissions do |permissions_page|
              scopes = %w[write delete]
              permissions_page.add_role_permission(role_name: 'Developer', scopes: scopes)
              expect(permissions_page.alert_text).to eq('Actions must include read')
            end
          end
        end
      end

      context 'when owner deletes a permission' do
        it 'successfully deletes permissions',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/579769',
          quarantine: { issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/29022',
                        type: 'flaky' } do
          Page::Main::Menu.perform(&:sign_out)
          Flow::Login.sign_in(as: owner)
          project.visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_visibility_project_features_permissions do |permissions_page|
              scopes = %w[read]
              permissions_page.add_user_permission(username: reporter.username, scopes: scopes)
              permissions_page.delete_user_permission(username: reporter.username)
              expect(permissions_page).not_to have_user_permission(username: reporter.username, scopes: scopes)
            end
          end
        end
      end
    end
  end
end
