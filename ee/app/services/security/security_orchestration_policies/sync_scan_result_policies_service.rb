# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncScanResultPoliciesService
      def initialize(configuration)
        @configuration = configuration
        @sync_project_service = SyncScanResultPoliciesProjectService.new(configuration)
      end

      def execute
        measure(:gitlab_security_policies_update_configuration_duration_seconds) do
          delay = 0
          projects.each_batch do |projects|
            projects.each do |project|
              @sync_project_service.execute(project.id, { delay: delay })
            end

            delay += 10.seconds
          end
        end
      end

      private

      attr_reader :configuration

      delegate :measure, to: ::Security::SecurityOrchestrationPolicies::ObserveHistogramsService

      def projects
        @projects ||= if configuration.namespace?
                        configuration.namespace.all_project_ids
                      else
                        Project.id_in(configuration.project_id)
                      end
      end
    end
  end
end
