# frozen_string_literal: true

module Security
  module ScanProfiles
    class AttachService
      include BaseServiceUtility
      include Gitlab::ExclusiveLeaseHelpers

      BATCH_SIZE = 500
      LEASE_TIMEOUT = 5.minutes
      MAX_RETRY = 25
      RETRY_DELAY = 30.seconds

      def initialize(group, scan_profile, traverse_hierarchy: true, retry_count: 0)
        @group = group
        @scan_profile = scan_profile
        @traverse_hierarchy = traverse_hierarchy
        @retry_count = retry_count
      end

      def execute
        return error('Scan profile does not belong to group hierarchy') unless valid_namespace?

        attach_profile_to_projects
        success
      rescue StandardError => e
        Gitlab::ErrorTracking.track_exception(e, {
          group_id: group.id,
          scan_profile_id: scan_profile.id
        })
        error('Failed to attach scan profile to projects')
      end

      private

      attr_reader :group, :scan_profile, :traverse_hierarchy, :retry_count

      def valid_namespace?
        scan_profile.namespace_id == group.root_ancestor.id
      end

      def attach_profile_to_projects
        if traverse_hierarchy
          cursor = { current_id: group.id, depth: [group.id] }
          iterator = Gitlab::Database::NamespaceEachBatch.new(namespace_class: Group, cursor: cursor)

          iterator.each_batch(of: BATCH_SIZE) do |namespace_ids|
            namespace_ids.each do |namespace_id|
              process_namespace_with_lock(namespace_id)
            end
          end
        else
          process_namespace_with_lock(group.id)
        end
      end

      def process_namespace_with_lock(namespace_id)
        relation = Project.in_namespace(namespace_id).order_by_primary_key

        relation.each_batch(of: BATCH_SIZE) do |batch|
          insert_batch_with_lock(namespace_id, batch)
        end
      end

      def insert_batch_with_lock(namespace_id, batch)
        lease_key = Security::ScanProfiles.update_lease_key(namespace_id)

        in_lock(lease_key, ttl: LEASE_TIMEOUT, retries: 0) do
          batch_ids = batch.pluck_primary_key
          bulk_insert_profile_projects(batch_ids)
        end
      rescue Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError
        handle_lock_failure(namespace_id)
      end

      def handle_lock_failure(namespace_id)
        if retry_count < MAX_RETRY
          Security::ScanProfiles::AttachWorker.perform_in(
            RETRY_DELAY, namespace_id, scan_profile.id, false, retry_count + 1)
        else
          Gitlab::ErrorTracking.track_exception(
            StandardError.new('Max retries reached for attaching scan profile'),
            {
              namespace_id: namespace_id,
              scan_profile_id: scan_profile.id,
              retry_count: retry_count
            }
          )
        end
      end

      def bulk_insert_profile_projects(batch_ids)
        timestamp = Time.current

        attributes = batch_ids.map do |project_id|
          {
            project_id: project_id,
            security_scan_profile_id: scan_profile.id,
            created_at: timestamp,
            updated_at: timestamp
          }
        end

        Security::ScanProfileProject.insert_all(
          attributes,
          unique_by: [:project_id, :security_scan_profile_id]
        )
      end
    end
  end
end
