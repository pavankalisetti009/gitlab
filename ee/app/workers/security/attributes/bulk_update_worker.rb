# frozen_string_literal: true

module Security
  module Attributes
    class BulkUpdateWorker
      include ApplicationWorker

      data_consistency :sticky
      feature_category :security_asset_inventories
      idempotent!

      def perform(project_ids, attribute_ids, mode, user_id)
        user = User.find_by_id(user_id)
        return unless user

        projects = Project.by_ids(project_ids).with_namespaces
        projects = projects.inc_routes.with_project_to_security_attributes if mode == 'REPLACE'

        projects.each do |project|
          process_project(project, attribute_ids, mode, user)
        rescue StandardError => e
          # Store error for future use - for now just log it
          Gitlab::ErrorTracking.track_exception(e, {
            project_id: project.id,
            attribute_ids: attribute_ids,
            mode: mode,
            user_id: user_id
          })
        end
      end

      private

      def process_project(project, attribute_ids, mode, user)
        return unless Feature.enabled?(:security_categories_and_attributes, project.namespace.root_ancestor)

        unless user.can?(:admin_project, project) &&
            user.can?(:admin_security_attributes, project.namespace.root_ancestor)
          return
        end

        service_params = build_service_params(project, attribute_ids, mode)

        ::Security::Attributes::UpdateProjectAttributesService.new(
          project: project,
          current_user: user,
          params: service_params
        ).execute
      end

      def build_service_params(project, attribute_ids, mode)
        {
          attributes: {
            add_attribute_ids: mode == 'REMOVE' ? [] : attribute_ids,
            remove_attribute_ids: remove_attribute_ids(project, attribute_ids, mode)
          }
        }
      end

      def remove_attribute_ids(project, attribute_ids, mode)
        return attribute_ids if mode == 'REMOVE'
        return [] if mode == 'ADD'

        # For the 'REPLACE' mode, we select all existing attribute ids
        project.project_to_security_attributes.pluck_security_attribute_id
      end
    end
  end
end
