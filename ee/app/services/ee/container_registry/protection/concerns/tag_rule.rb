# frozen_string_literal: true

module EE
  module ContainerRegistry
    module Protection
      module Concerns
        module TagRule
          extend ActiveSupport::Concern
          extend ::Gitlab::Utils::Override

          override :protected_for_delete?
          def protected_for_delete?(project:, current_user:)
            if ::Feature.enabled?(:container_registry_immutable_tags, project) &&
                project.licensed_feature_available?(:container_registry_immutable_tag_rules) &&
                project.container_registry_protection_tag_rules.immutable.exists? &&
                project.has_container_registry_tags?
              return true
            end

            super
          end
        end
      end
    end
  end
end
