# frozen_string_literal: true

module Mutations
  module Security
    module Categories
      class Update < BaseMutation
        graphql_name 'SecurityCategoryUpdate'

        authorize :admin_security_attributes

        argument :description, GraphQL::Types::String,
          required: false,
          description: 'Description of the security category.'
        argument :id, ::Types::GlobalIDType[::Security::Category],
          required: false,
          description: 'Global ID of the security category.'
        argument :name, GraphQL::Types::String,
          required: false,
          description: 'Name of the security category.'
        argument :namespace_id, ::Types::GlobalIDType[::Namespace],
          required: true,
          description: 'Global ID of the category namespace.'
        argument :template_type, Types::Security::CategoryTemplateTypeEnum,
          required: false,
          description: 'Template type for predefined categories. Will be used if no Category ID is given.'

        field :security_category, Types::Security::CategoryType,
          null: true,
          description: 'Updated security category.'

        def resolve(id: nil, template_type: nil, namespace_id: nil, **params)
          namespace = authorized_find!(id: namespace_id)
          unless Feature.enabled?(:security_categories_and_attributes, namespace.root_ancestor)
            raise_resource_not_available_error!
          end

          validate_arguments(id, template_type)
          category_result = ::Security::Categories::FindOrCreateService.new(
            category_id: parse_gid(id), template_type: template_type, namespace: namespace, current_user: current_user
          ).execute
          return { errors: category_result.errors } if category_result.error?

          category = category_result.payload[:category]
          result = ::Security::Categories::UpdateService.new(
            category: category, current_user: current_user, params: params
          ).execute

          {
            security_category: result.success? ? result.payload[:category] : nil,
            errors: result.errors
          }
        end

        def validate_arguments(id, template_type)
          if id.blank? && template_type.blank?
            raise Gitlab::Graphql::Errors::ArgumentError, 'Either Category id or templateType must be provided'
          end

          return unless id.present? && template_type.present?

          raise Gitlab::Graphql::Errors::ArgumentError, 'Only one of id or templateType should be provided'
        end

        def parse_gid(gid)
          return unless gid

          GitlabSchema.parse_gid(gid, expected_type: ::Security::Category).model_id
        end
      end
    end
  end
end
