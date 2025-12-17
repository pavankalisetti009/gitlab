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

        def perform(group_id, user_id = nil, flow_references = nil)
          group = Group.find_by_id(group_id)
          return unless group

          user = user_id ? User.find_by_id(user_id) : nil

          seed_foundational_flows(group, user)

          convert_references_to_ids(flow_references) if flow_references

          sync_groups(group, user, skip_parent: true)

          sync_projects(group, user)
        end

        private

        def seed_foundational_flows(group, user)
          ::Ai::Catalog::Flows::SeedFoundationalFlowsService.new(
            current_user: user,
            organization: group.organization
          ).execute
        end

        def convert_references_to_ids(flow_references)
          references = flow_references || []
          return [] if references.empty?

          reference_to_id = ::Ai::Catalog::Item.foundational_flow_ids_for_references(references)
          references.filter_map { |ref| reference_to_id[ref] }
        end

        def sync_groups(group, user, skip_parent: false)
          unless skip_parent
            ::Ai::Catalog::Flows::SyncFoundationalFlowsService.new(
              group,
              current_user: user
            ).execute
          end

          group.descendants.each_batch do |batch|
            batch.each do |descendant_group|
              ::Ai::Catalog::Flows::SyncFoundationalFlowsService.new(
                descendant_group,
                current_user: user
              ).execute
            end
          end
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
