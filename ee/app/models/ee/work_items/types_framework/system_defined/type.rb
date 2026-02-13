# frozen_string_literal: true

module EE
  module WorkItems
    module TypesFramework
      module SystemDefined
        module Type
          extend ActiveSupport::Concern
          extend ::Gitlab::Utils::Override

          BASE_TYPES = [
            ::WorkItems::TypesFramework::SystemDefined::Definitions::Epic.configuration,
            ::WorkItems::TypesFramework::SystemDefined::Definitions::KeyResult.configuration,
            ::WorkItems::TypesFramework::SystemDefined::Definitions::Objective.configuration,
            ::WorkItems::TypesFramework::SystemDefined::Definitions::Requirement.configuration,
            ::WorkItems::TypesFramework::SystemDefined::Definitions::TestCase.configuration
          ].freeze

          class_methods do
            extend ::Gitlab::Utils::Override

            override :fixed_items
            def fixed_items
              super + BASE_TYPES
            end
          end

          BASE_TYPES.each do |type|
            define_method :"#{type[:base_type]}?" do
              base_type == type[:base_type]
            end
          end

          override :widgets
          def widgets(resource_parent)
            # Only include widgets if the resource_parent has the appropriate license or if the widget is not licensed
            super.reject { |widget_def| !widget_def.licensed?(resource_parent) }
          end

          def status_lifecycle_for(namespace_id)
            custom_lifecycle_for(namespace_id) || system_defined_lifecycle
          end

          def custom_status_enabled_for?(namespace_id)
            return false unless namespace_id

            ::WorkItems::TypeCustomLifecycle.exists?(
              work_item_type_id: id,
              namespace_id: namespace_id
            )
          end

          def custom_lifecycle_for(namespace_id)
            return unless namespace_id

            ::WorkItems::Statuses::Custom::Lifecycle
              .includes(:statuses, :default_open_status, :default_closed_status, :default_duplicate_status)
              .joins(:type_custom_lifecycles)
              .find_by(
                namespace_id: namespace_id,
                type_custom_lifecycles: { work_item_type_id: id, namespace_id: namespace_id }
              )
          end

          def system_defined_lifecycle
            ::WorkItems::Statuses::SystemDefined::Lifecycle.of_work_item_base_type(base_type)
          end

          private

          override :supported_conversion_base_types
          def supported_conversion_base_types(resource_parent, user)
            return [] unless supports_conversion?

            all_types = super - BASE_TYPES.pluck(:base_type) # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- It's an array of hashed not active record relations

            ee_base_types = self.class.all.filter_map do |type|
              if type.licensed? && resource_parent.licensed_feature_available?(type.license_name.to_sym)
                type.base_type.to_s
              end
            end.compact

            group = resource_parent.is_a?(Group) ? resource_parent : resource_parent.group

            ee_base_types -= %w[epic] unless Ability.allowed?(user, :create_epic, group)

            project = if resource_parent.is_a?(Project)
                        resource_parent
                      elsif resource_parent.respond_to?(:project)
                        resource_parent.project.presence
                      end

            ee_base_types -= %w[objective key_result] unless project && ::Feature.enabled?(:okrs_mvc, project)

            all_types + ee_base_types
          end

          override :authorized_types
          def authorized_types(types, resource_parent, licenses_for_relation)
            return super unless licenses_for_relation

            types.select do |type|
              license_name = licenses_for_relation[type.base_type]
              next type unless license_name

              resource_parent&.licensed_feature_available?(license_name)
            end
          end

          def supports_conversion?
            value = configuration_class.try(:supports_conversion?)
            value.nil? ? true : value
          end
        end
      end
    end
  end
end
