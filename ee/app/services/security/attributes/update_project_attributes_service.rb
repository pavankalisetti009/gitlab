# frozen_string_literal: true

module Security
  module Attributes
    class UpdateProjectAttributesService < BaseService
      include Gitlab::Utils::StrongMemoize

      MAX_ATTRIBUTES = 50

      def initialize(project:, current_user:, params:)
        @project = project
        @current_user = current_user
        @params = params
      end

      def execute
        unless Feature.enabled?(:security_categories_and_attributes, root_namespace)
          raise Gitlab::Access::AccessDeniedError
        end

        return UnauthorizedError unless permitted?
        return attribute_limit_error if exceeds_attribute_limit?

        validate_attributes
        return error_response('Invalid attributes', errors: validation_errors) if validation_errors.present?

        apply_changes

        ServiceResponse.success(payload: {
          project: project.reset,
          added_count: associations_to_create.size,
          removed_count: associations_to_destroy.size
        })
      rescue ActiveRecord::RecordInvalid
        error_response('Failed to update security attributes')
      end

      private

      attr_reader :project, :current_user, :params

      def validation_errors
        []
      end
      strong_memoize_attr :validation_errors

      def permitted?
        current_user.can?(:admin_project, project) &&
          current_user.can?(:admin_security_attributes, root_namespace)
      end

      def root_namespace
        project.namespace.root_ancestor
      end
      strong_memoize_attr :root_namespace

      def add_attribute_ids
        params.dig(:attributes, :add_attribute_ids)&.map(&:to_i) || []
      end
      strong_memoize_attr :add_attribute_ids

      def remove_attribute_ids
        params.dig(:attributes, :remove_attribute_ids)&.map(&:to_i) || []
      end
      strong_memoize_attr :remove_attribute_ids

      def associations_to_create
        (add_attribute_ids - existing_attributes.pluck_id).filter_map do |attribute_id|
          security_attribute = all_attributes_by_id[attribute_id]

          if security_attribute.blank?
            validation_errors << "Security attribute not found: #{attribute_id}"
            next
          end

          project.project_to_security_attributes.build(
            security_attribute: security_attribute,
            traversal_ids: project.namespace.traversal_ids,
            created_at: now,
            updated_at: now
          )
        end
      end
      strong_memoize_attr :associations_to_create

      def now
        Time.zone.now
      end
      strong_memoize_attr :now

      def associations_to_destroy
        project.project_to_security_attributes.by_attribute_id(remove_attribute_ids).to_a
      end
      strong_memoize_attr :associations_to_destroy

      def exceeds_attribute_limit?
        add_attribute_ids.size + remove_attribute_ids.size > MAX_ATTRIBUTES
      end

      def attribute_limit_error
        error_response("Cannot process more than #{MAX_ATTRIBUTES} attributes at once")
      end

      def error_response(message, **payload)
        ServiceResponse.error(message: message, payload: { **payload })
      end

      def all_attributes_by_id
        (Security::Attribute.id_in(add_attribute_ids).include_category + existing_attributes).index_by(&:id)
      end
      strong_memoize_attr :all_attributes_by_id

      def existing_attributes
        project.security_attributes.include_category
      end
      strong_memoize_attr :existing_attributes

      def apply_changes
        Security::ProjectToSecurityAttribute.transaction do
          if associations_to_destroy.present?
            Security::ProjectToSecurityAttribute.id_in(associations_to_destroy.map(&:id)).delete_all
          end

          Security::ProjectToSecurityAttribute.bulk_insert!(associations_to_create, skip_duplicates: true)
        end
      end

      def validate_attributes
        associations_to_create.each do |project_to_security_attribute|
          validate_one_attribute_per_category(project_to_security_attribute.security_attribute)
        end
      end

      def existing_single_select_categories
        existing_attributes.filter_map do |attribute|
          attribute.security_category_id unless attribute.security_category.multiple_selection
        end.to_set
      end
      strong_memoize_attr :existing_single_select_categories

      def validate_one_attribute_per_category(attribute)
        category = attribute.security_category
        return if category.multiple_selection

        category_id = category.id
        category_already_present = existing_single_select_categories.include?(category_id)
        existing_single_select_categories.add(category_id)
        return unless category_already_present

        validation_errors << "Cannot add multiple attributes from the same category #{category_id}"
      end
    end
  end
end
