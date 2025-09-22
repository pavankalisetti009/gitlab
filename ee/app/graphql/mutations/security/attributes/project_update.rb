# frozen_string_literal: true

module Mutations
  module Security
    module Attributes
      class ProjectUpdate < BaseMutation
        graphql_name 'SecurityAttributeProjectUpdate'

        authorize :admin_security_attributes

        argument :project_id, ::Types::GlobalIDType[::Project],
          required: true,
          description: 'Global ID of the project.'

        argument :add_attribute_ids, [::Types::GlobalIDType[::Security::Attribute]],
          required: false,
          description: 'Global IDs of the security attributes to add to the project.',
          prepare: ->(gids, _) { GitlabSchema.parse_gids(gids, expected_type: ::Security::Attribute).map(&:model_id) }

        argument :remove_attribute_ids, [::Types::GlobalIDType[::Security::Attribute]],
          required: false,
          description: 'Global IDs of the security attributes to remove from the project.',
          prepare: ->(gids, _) { GitlabSchema.parse_gids(gids, expected_type: ::Security::Attribute).map(&:model_id) }

        argument :attribute_template_types, [Types::Security::AttributeTemplateTypeEnum],
          required: false,
          description: 'Types of predefined security attributes to add to the project. ' \
            'Will be used only if no addAttributeIds are provided.'

        field :added_count, GraphQL::Types::Int,
          null: true,
          description: 'Number of attributes added.'

        field :project, Types::ProjectType,
          null: true,
          description: 'Updated project.'

        field :removed_count, GraphQL::Types::Int,
          null: true,
          description: 'Number of attributes removed.'

        def resolve(project_id:, add_attribute_ids: [], remove_attribute_ids: [], attribute_template_types: [])
          project = authorized_find!(id: project_id)
          validate_feature_flag(project)

          add_ids = resolve_attribute_ids_to_add(add_attribute_ids, attribute_template_types, project)
          return error_response(add_ids[:errors]) if add_ids[:errors].present?

          if no_attributes_to_process?(add_ids[:attribute_ids], remove_attribute_ids)
            return error_response(['No attributes found for addition or removal'])
          end

          execute_update_service(project, add_ids[:attribute_ids], remove_attribute_ids)
        end

        private

        def validate_feature_flag(project)
          return if Feature.enabled?(:security_categories_and_attributes, project.namespace.root_ancestor)

          raise_resource_not_available_error!
        end

        def resolve_attribute_ids_to_add(add_attribute_ids, attribute_template_types, project)
          return { attribute_ids: add_attribute_ids, errors: [] } if add_attribute_ids.present?
          return { attribute_ids: [], errors: [] } if attribute_template_types.blank?

          process_attribute_template_types(attribute_template_types, project.namespace.root_ancestor)
        end

        def process_attribute_template_types(attribute_template_types, namespace)
          predefined_result = create_predefined_attributes(namespace)
          return { attribute_ids: [], errors: [predefined_result.message] } unless predefined_result.success?

          attribute_ids = fetch_attribute_ids_by_template_types(attribute_template_types, namespace)
          { attribute_ids: attribute_ids, errors: [] }
        end

        def create_predefined_attributes(namespace)
          ::Security::Categories::CreatePredefinedService.new(namespace: namespace, current_user: current_user).execute
        end

        def fetch_attribute_ids_by_template_types(attribute_template_types, namespace)
          ::Security::Attribute.by_namespace(namespace.id).by_template_type(attribute_template_types).pluck_id
        end

        def no_attributes_to_process?(add_ids, remove_ids)
          add_ids.empty? && remove_ids.empty?
        end

        def execute_update_service(project, add_ids, remove_ids)
          result = ::Security::Attributes::UpdateProjectAttributesService.new(
            project: project,
            current_user: current_user,
            params: {
              attributes: {
                add_attribute_ids: add_ids,
                remove_attribute_ids: remove_ids
              }
            }
          ).execute

          result.success? ? success_response(result.payload) : error_response([result.message])
        end

        def success_response(payload)
          {
            project: payload[:project],
            added_count: payload[:added_count],
            removed_count: payload[:removed_count],
            errors: []
          }
        end

        def error_response(errors)
          {
            project: nil,
            added_count: nil,
            removed_count: nil,
            errors: errors
          }
        end
      end
    end
  end
end
