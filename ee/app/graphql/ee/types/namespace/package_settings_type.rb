# frozen_string_literal: true

module EE
  module Types
    module Namespace # rubocop:disable Gitlab/BoundedContexts -- Existing module
      module PackageSettingsType
        extend ActiveSupport::Concern

        prepended do
          field :audit_events_enabled, GraphQL::Types::Boolean,
            null: true,
            experiment: { milestone: '17.10' },
            description: 'Indicates whether audit events are created when publishing ' \
              'or deleting a package in the namespace (Premium and Ultimate only). ' \
              'Returns `null` if `package_registry_audit_events` feature flag is disabled.'

          def audit_events_enabled
            return if ::Feature.disabled?(:package_registry_audit_events, ::Feature.current_request)

            object.audit_events_enabled
          end
        end
      end
    end
  end
end
