# frozen_string_literal: true

namespace :gitlab do
  namespace :vulnerabilities do
    desc 'Fix vulnerabilities affected by https://gitlab.com/gitlab-org/gitlab/-/issues/521907'
    task :fix_auto_resolved_vulnerabilities, [:namespace_id] => :environment do |_, args|
      include Gitlab::Database::Migrations::BatchedBackgroundMigrationHelpers

      namespace_id = args[:namespace_id]

      unless /(\d+|instance)/.match?(namespace_id)
        puts "#{namespace_id} is not a number."
        puts 'Use `gitlab-rake \'gitlab:vulnerabilities:fix_auto_resolved_vulnerabilities[instance]\'` ' \
          'to perform an instance migration.'
        exit 1
      end

      instance_migration = namespace_id == 'instance'
      if !instance_migration && Namespace.find(namespace_id).parent.present?
        puts 'Namespace must be top-level.'
        exit 1
      end

      namespace_id = namespace_id.to_i unless instance_migration

      def version
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def connection
        SecApplicationRecord.connection
      end

      queue_batched_background_migration(
        'FixVulnerabilitiesTransitionedFromDismissedToResolved',
        :vulnerability_reads,
        :vulnerability_id,
        namespace_id,
        gitlab_schema: :gitlab_sec
      )
    end
  end
end
