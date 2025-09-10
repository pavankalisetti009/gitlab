# frozen_string_literal: true

module Mutations
  module Security
    module Attributes
      class Create < BaseMutation
        graphql_name 'SecurityAttributeCreate'

        authorize :admin_security_attributes

        argument :attributes, [Types::Security::AttributeInputType],
          required: true,
          description: 'Attributes to create.'

        argument :category_id, ::Types::GlobalIDType[::Security::Category],
          required: false,
          description: 'Global ID of the security category.'

        argument :namespace_id, ::Types::GlobalIDType[::Namespace],
          required: false,
          description: 'Global ID of the namespace. Will be used if no Category ID is given.'

        argument :template_type, Types::Security::CategoryTemplateTypeEnum,
          required: false,
          description: 'Template type for predefined categories. Will be used if no Category ID is given.'

        field :security_attributes, [Types::Security::AttributeType],
          null: true,
          description: 'Created security attributes.'

        def resolve(attributes:, category_id: nil, template_type: nil, namespace_id: nil)
          validate_arguments(category_id, template_type, namespace_id)

          category = category_id ? authorized_find!(id: category_id) : nil
          namespace = namespace_id ? authorized_find!(id: namespace_id) : category&.namespace

          unless Feature.enabled?(:security_categories_and_attributes, namespace.root_ancestor)
            raise_resource_not_available_error!
          end

          category_result = ::Security::Categories::FindOrCreateService.new(
            category_id: category&.id,
            template_type: template_type,
            namespace: namespace,
            current_user: current_user
          ).execute
          return { errors: category_result.errors } if category_result.error?

          category = category_result.payload[:category]
          validate_category_attribute_limit(category, attributes.length)

          result = ::Security::Attributes::CreateService.new(
            category: category,
            namespace: namespace,
            current_user: current_user,
            params: { attributes: attributes }
          ).execute

          {
            security_attributes: result.success? ? result.payload[:attributes] : nil,
            errors: result.errors
          }
        end

        private

        def validate_arguments(category_id, template_type, namespace_id)
          if category_id.present?
            if namespace_id.present? || template_type.present?
              raise Gitlab::Graphql::Errors::ArgumentError,
                'When categoryId is provided, namespaceId and templateType should not be specified'
            end
          elsif namespace_id.blank? || template_type.blank?
            raise Gitlab::Graphql::Errors::ArgumentError,
              'When categoryId is not provided, both namespaceId and templateType must be specified'
          end
        end

        def validate_category_attribute_limit(category, new_attributes_count)
          return unless category

          current_count = category.security_attributes.count
          expected_attribute_count = current_count + new_attributes_count
          return unless expected_attribute_count > ::Security::Category::MAX_ATTRIBUTES

          raise Gitlab::Graphql::Errors::ArgumentError,
            "Category cannot have more than #{::Security::Category::MAX_ATTRIBUTES} attributes."
        end
      end
    end
  end
end
