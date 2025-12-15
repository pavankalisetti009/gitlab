# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class CascadeSyncFoundationalFlowsWorker
        include ApplicationWorker

        data_consistency :delayed
        feature_category :ai_abstraction_layer
        urgency :low
        worker_has_external_dependencies!
        idempotent!
        defer_on_database_health_signal :gitlab_main, [:namespace_settings, :project_settings], 1.minute

        def perform(group_id, user_id = nil)
          group = Group.find_by_id(group_id)
          return unless group

          user = user_id ? User.find_by_id(user_id) : nil

          seed_foundational_flows(group, user)

          sync_groups(group, user)

          sync_projects(group, user)
        end

        private

        def seed_foundational_flows(group, user)
          organization = group.organization
          return unless organization

          ::Ai::Catalog::Flows::SeedFoundationalFlowsService.new(
            current_user: user,
            organization: organization
          ).execute
        end

        def sync_groups(group, user)
          ::Ai::Catalog::Flows::SyncFoundationalFlowsService.new(
            group,
            current_user: user
          ).execute
        end

        def sync_projects(group, user)
          group.all_projects.each_batch do |batch|
            batch.each do |project|
              ::Ai::Catalog::Flows::SyncFoundationalFlowsService.new(
                project,
                current_user: user
              ).execute
            end
          end
        end
      end
    end
  end
end
