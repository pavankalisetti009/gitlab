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

        service_params = build_service_params(attribute_ids, mode)

        ::Security::Attributes::UpdateProjectAttributesService.new(
          project: project,
          current_user: user,
          params: service_params
        ).execute
      end

      def build_service_params(attribute_ids, mode)
        normalized_mode = mode.to_s.downcase
        raise ArgumentError, "Unsupported mode: #{mode}" unless %w[add remove].include?(normalized_mode)

        {
          attributes: {
            add_attribute_ids: normalized_mode == 'add' ? attribute_ids : [],
            remove_attribute_ids: normalized_mode == 'remove' ? attribute_ids : []
          }
        }
      end
    end
  end
end
