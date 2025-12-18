# frozen_string_literal: true

module Security
  module ScanProfiles
    class CleanOldNamespaceConnectionsService
      PROJECT_BATCH_SIZE = 100

      def self.execute(group_id)
        new(group_id).execute
      end

      def initialize(group_id)
        @group_id = group_id
      end

      def execute
        return unless group.present?

        root_ancestor = group.root_ancestor
        project_ids.each_slice(PROJECT_BATCH_SIZE) do |id_batch|
          Security::ScanProfileProject.by_project_id(id_batch).not_in_root_namespace(root_ancestor).delete_all
        end
      end

      attr_reader :group_id

      private

      def group
        @group ||= Group.find_by_id(group_id)
      end

      def project_ids
        Gitlab::Database::NamespaceProjectIdsEachBatch.new(group_id: group_id).execute
      end
    end
  end
end
