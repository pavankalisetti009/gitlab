# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    only: { job: 'gdk-instance-secrets-manager' },
    feature_category: :secrets_management
  ) do
    describe 'Secrets Manager Feature Provision' do
      include QA::EE::Support::Helpers::SecretsManagement::SecretsManagerHelper # rubocop: disable Cop/InjectEnterpriseEditionModule -- Helpers are added this way
      let(:owner) { create(:user) }
      let(:project) { create(:project, :with_readme, name: 'secrets-manager-test-project') }

      before do
        project.add_member(owner, Resource::Members::AccessLevel::OWNER)
      end

      it 'enables and disables secrets manager feature',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/574677' do
        Flow::Login.sign_in(as: owner)
        skip "OpenBao instance is not reachable" unless openbao_healthy?
        project.visit!
        Page::Project::Menu.perform(&:go_to_general_settings)

        Page::Project::Settings::Main.perform do |settings|
          settings.expand_visibility_project_features_permissions do |permissions|
            expect(permissions).to have_secrets_manager_section
            permissions.enable_secrets_manager

            Support::Waiter.wait_until(max_duration: 60, sleep_interval: 2) do
              permissions.secrets_manager_enabled?
            end

            expect(permissions).to be_secrets_manager_enabled
          end
        end

        # TODO: Replace with UI interaction once deprovisioning UI is available
        deprovision_response = deprovision_secrets_manager(project)
        expect(deprovision_response[:errors]).to be_empty
        expect(deprovision_response[:projectSecretsManager][:status]).to eq('DEPROVISIONING')
        expect(deprovision_response[:projectSecretsManager][:project][:fullPath]).to eq(project.full_path)
      end
    end
  end
end
