# frozen_string_literal: true

module EE
  module Resolvers
    module WorkItems
      module DescriptionTemplateContentResolver
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        private

        override :authorize_template!
        def authorize_template!(template_project, from_namespace)
          # If the instance wide default template repository is this one, we don't need to authorize. Assume that all
          # users in the instance can read the template
          if ::License.feature_available?(:custom_file_templates) &&
              ::Gitlab::CurrentSettings.file_template_project == template_project
            return
          end

          # If a target namespace is provided, we'll check if:
          # * The current user can read this namespace
          # * The checked_file_template_project of any ancestor of this namespace is the template's project
          if from_namespace
            target_namespace = Routable.find_by_full_path(from_namespace)
            target_namespace = target_namespace.project_namespace if target_namespace.is_a?(Project)

            authorize!(target_namespace)

            return if target_namespace.self_and_ancestors(skope: ::Namespace).any? do |n|
              n.checked_file_template_project&.id == template_project.id
            end
          end

          # If we didn't return from the above 2 checks, check if we can at least read the namespace of the project
          # related to the template
          super
        end
      end
    end
  end
end
