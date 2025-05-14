# frozen_string_literal: true

namespace :gitlab do
  namespace :vulnerabilities do
    desc 'Fix vulnerabilities affected by https://gitlab.com/gitlab-org/gitlab/-/issues/521907'
    task :fix_auto_resolved_vulnerabilities, [:namespace_id, :instance] => :environment do |_, args|
      include Gitlab::Database::Migrations::BatchedBackgroundMigrationHelpers

      namespace_id, instance = args.values_at(:namespace_id, :instance)
      if namespace_id.present? && instance
        puts "Can't perform an instance migration with a namespace_id"
        exit 1
      end

      if Namespace.find(namespace_id).parent.present?
        puts 'Namespace must be top-level'
        exit 1
      end

      queue_batched_background_migration(
        FixVulnerabilitiesTransitionedFromDismissedToResolved,
        :vulnerability_reads,
        :vulnerability_id,
        namespace_id,
        instance
      )
    end
  end
end
