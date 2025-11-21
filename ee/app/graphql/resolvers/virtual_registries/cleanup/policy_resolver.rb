# frozen_string_literal: true

module Resolvers
  module VirtualRegistries
    module Cleanup
      class PolicyResolver < BaseResolver
        type ::Types::VirtualRegistries::Cleanup::PolicyType, null: true

        alias_method :group, :object

        def resolve(**_args)
          return unless virtual_registry_available?
          return unless virtual_registry_cleanup_policies_available?

          ::VirtualRegistries::Cleanup::Policy.find_by_group_id(group.id)
        end

        private

        def authorized?(**_args)
          current_user&.can?(:admin_virtual_registry, group.virtual_registry_policy_subject)
        end

        def virtual_registry_available?
          ::VirtualRegistries::Packages::Maven.virtual_registry_available?(
            group, current_user, :admin_virtual_registry
          )
        end

        def virtual_registry_cleanup_policies_available?
          ::Feature.enabled?(:virtual_registry_cleanup_policies, Feature.current_request)
        end
      end
    end
  end
end
