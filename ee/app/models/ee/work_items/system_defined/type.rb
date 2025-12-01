# frozen_string_literal: true

module EE
  module WorkItems
    module SystemDefined
      module Type
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        LICENSED_WIDGETS = {
          iterations: ::WorkItems::Widgets::Iteration,
          issue_weights: ::WorkItems::Widgets::Weight,
          requirements: [
            ::WorkItems::Widgets::VerificationStatus,
            ::WorkItems::Widgets::RequirementLegacy,
            ::WorkItems::Widgets::TestReports
          ],
          issuable_health_status: ::WorkItems::Widgets::HealthStatus,
          okrs: ::WorkItems::Widgets::Progress,
          epic_colors: ::WorkItems::Widgets::Color,
          custom_fields: ::WorkItems::Widgets::CustomFields,
          security_dashboard: ::WorkItems::Widgets::Vulnerabilities,
          work_item_status: ::WorkItems::Widgets::Status
        }.freeze

        LICENSED_TYPES = { epic: :epics, objective: :okrs, key_result: :okrs, requirement: :requirements }.freeze

        LICENSED_HIERARCHY_TYPES = {
          issue: { parent: { epic: :epics } },
          epic: { parent: { epic: :subepics }, child: { epic: :subepics, issue: :epics } }
        }.freeze

        class_methods do
          extend ::Gitlab::Utils::Override

          override :fixed_items
          def fixed_items
            super + [
              ::WorkItems::SystemDefined::Types::Epic.configuration,
              ::WorkItems::SystemDefined::Types::KeyResult.configuration,
              ::WorkItems::SystemDefined::Types::Objective.configuration,
              ::WorkItems::SystemDefined::Types::Requirement.configuration,
              ::WorkItems::SystemDefined::Types::TestCase.configuration
            ]
          end
        end

        private

        override :supported_conversion_base_types
        def supported_conversion_base_types(resource_parent, user)
          ee_base_types = LICENSED_TYPES.flat_map do |type, licensed_feature|
            type.to_s if resource_parent.licensed_feature_available?(licensed_feature.to_sym)
          end.compact

          group = resource_parent.is_a?(Group) ? resource_parent : resource_parent.group

          ee_base_types -= %w[epic] unless Ability.allowed?(user, :create_epic, group)

          project = if resource_parent.is_a?(Project)
                      resource_parent
                    elsif resource_parent.respond_to?(:project)
                      resource_parent.project.presence
                    end

          ee_base_types -= %w[objective key_result] unless project && ::Feature.enabled?(:okrs_mvc, project)

          super + ee_base_types
        end

        override :authorized_types
        def authorized_types(types, resource_parent, relation)
          licenses_for_relation = LICENSED_HIERARCHY_TYPES[base_type.to_sym].try(:[], relation)
          return super unless licenses_for_relation

          types.select do |type|
            license_name = licenses_for_relation[type.base_type.to_sym]
            next type unless license_name

            resource_parent&.licensed_feature_available?(license_name)
          end
        end
      end
    end
  end
end
