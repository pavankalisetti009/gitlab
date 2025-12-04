# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :requires_admin,
    :skip_live_env, # We need to enable local requests to use a local mock streaming server
    feature_category: :compliance_management,
    feature_flag: { name: :disable_audit_event_streaming }
  ) do
    describe 'Instance audit event streaming' do
      let!(:mock_service) { QA::Support::AuditEventStreamingService.new }
      let!(:stream_destination_url) { mock_service.destination_url }

      let(:target_details) { entity_path }
      let(:event_types) { %w[remove_ssh_key group_created project_created user_created repository_git_operation] }

      let(:headers) do
        {
          'Test-Header1': 'instance event streaming',
          'Test-Header2': 'destination via api'
        }
      end

      let(:stream_destination) do
        EE::Resource::InstanceExternalStreamingDestination.fabricate_via_api! do |resource|
          resource.config = { 'url' => stream_destination_url }
        end
      end

      before do
        ensure_local_requests_enabled!
        stream_destination.add_headers(headers)
        stream_destination.add_filters(event_types)
        Runtime::Feature.disable(:disable_audit_event_streaming)

        mock_service.wait_for_streaming_to_start(event_type: 'remove_ssh_key', entity_type: 'User') do
          Resource::SSHKey.fabricate_via_api!.remove_via_api!
        end
      end

      after do |example|
        stream_destination.remove_via_api!

        mock_service.container_logs if example.exception
        mock_service.teardown!
      end

      context 'when a group is created' do
        let(:entity_path) { create(:group).full_path }

        include_examples 'streamed events', 'group_created', 'Group', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/415874'
      end

      context 'when a project is created', quarantine: {
        type: :investigating,
        issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/427266'
      } do
        # Create a group first so its audit event is streamed before we check for the create project event
        let!(:group) { create(:group) }
        let(:entity_path) { create(:project, group: group).full_path }

        include_examples 'streamed events', 'project_created', 'Project', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/415875'
      end

      context 'when a user is created', quarantine: {
        type: :investigating,
        issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/427266'
      } do
        let(:entity_path) { create(:user).username }

        include_examples 'streamed events', 'user_created', 'User', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/415876'
      end

      context 'when a repository is cloned via SSH' do
        # Create the project and key first so their audit events are streamed before we check for the clone event
        let!(:key) { Resource::SSHKey.fabricate_via_api! }
        let!(:project) { create(:project, :with_readme) }

        # Clone the repo via SSH and then use the project path and name to confirm the event details
        let(:target_details) { project.name }
        let(:entity_path) do
          Git::Repository.perform do |repository|
            repository.uri = project.repository_ssh_location.uri
            repository.use_ssh_key(key)
            repository.clone
          end

          project.full_path
        end

        include_examples 'streamed events', 'repository_git_operation', 'Project', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/415972'
      end

      private

      # Ensure local requests are enabled before each test example.
      # This is called in before(:each) rather than before(:context) to handle cases where
      # the setting may be reset by other tests or environment changes during parallel execution.
      #
      # @return [void]
      def ensure_local_requests_enabled!
        QA::Runtime::Logger.info("Ensuring local requests are enabled for audit event streaming test")

        Runtime::ApplicationSettings.set_application_settings(
          allow_local_requests_from_web_hooks_and_services: true
        )

        # Verify the setting was actually applied to avoid race conditions
        QA::Support::Retrier.retry_until(
          max_duration: 10,
          sleep_interval: 1,
          message: 'Waiting for local requests setting to be enabled'
        ) do
          Runtime::ApplicationSettings.get_application_setting(
            :allow_local_requests_from_web_hooks_and_services
          ) == true
        end
      rescue StandardError => e
        QA::Runtime::Logger.error("Failed to enable local requests: #{e.message}")
        raise
      end
    end
  end
end
