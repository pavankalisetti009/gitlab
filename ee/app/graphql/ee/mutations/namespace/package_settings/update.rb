# frozen_string_literal: true

module EE
  module Mutations
    module Namespace # rubocop:disable Gitlab/BoundedContexts -- Existing module
      module PackageSettings
        module Update
          extend ActiveSupport::Concern
          extend ::Gitlab::Utils::Override

          prepended do
            argument :audit_events_enabled,
              ::GraphQL::Types::Boolean,
              required: false,
              experiment: { milestone: '17.10' },
              description: copy_field_description(::Types::Namespace::PackageSettingsType, :audit_events_enabled)
          end

          override :resolve
          def resolve(namespace_path:, **args)
            if ::Feature.disabled?(:package_registry_audit_events, ::Feature.current_request)
              args.delete(:audit_events_enabled)
            end

            super
          end
        end
      end
    end
  end
end
