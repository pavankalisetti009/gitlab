# frozen_string_literal: true

module Vulnerabilities
  module Archival
    class ScheduleWorker
      include ApplicationWorker
      include CronjobQueue

      feature_category :vulnerability_management
      data_consistency :sticky
      idempotent!

      BATCH_SIZE = 500
      DELAY_INTERVAL = 30.seconds.to_i

      def perform
        archive_before = 1.year.ago.to_date.to_s
        index = 1

        ProjectSetting.has_vulnerabilities.each_batch(of: BATCH_SIZE) do |relation|
          projects = Project.id_in(relation).with_group
          groups = projects.filter_map(&:group)

          next if groups.empty?

          ::Namespaces::Preloaders::GroupRootAncestorPreloader.new(groups).execute

          projects = projects.select do |project|
            Feature.enabled?(:vulnerability_archival, project.group.root_ancestor)
          end

          next unless projects.present?

          Vulnerabilities::Archival::ArchiveWorker.bulk_perform_in_with_contexts(
            index * DELAY_INTERVAL,
            projects,
            arguments_proc: ->(project) { [project.id, archive_before] },
            context_proc: ->(project) { { project: project } })

          index += 1
        end
      end
    end
  end
end
