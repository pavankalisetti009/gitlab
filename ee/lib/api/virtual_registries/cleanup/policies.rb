# frozen_string_literal: true

module API
  module VirtualRegistries
    module Cleanup
      class Policies < ::API::Base
        include ::API::Concerns::VirtualRegistries::SharedAuthentication

        feature_category :virtual_registry
        urgency :low

        helpers do
          include ::Gitlab::Utils::StrongMemoize

          def group
            find_group!(params[:id])
          end
          strong_memoize_attr :group

          def policy
            ::VirtualRegistries::Cleanup::Policy.find_by_group_id!(params[:id])
          end
          strong_memoize_attr :policy
        end

        after_validation do
          not_found! unless ::Feature.enabled?(:maven_virtual_registry, group)
          not_found! unless ::Gitlab.config.dependency_proxy.enabled

          unless group.licensed_feature_available?(:packages_virtual_registry) ||
              group.licensed_feature_available?(:container_virtual_registry)
            not_found!
          end

          not_found! unless ::VirtualRegistries::Setting.find_for_group(group).enabled

          authenticate!
          authorize! :admin_virtual_registry, group.virtual_registry_policy_subject
        end

        resource :groups, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
          params do
            requires :id, types: [String, Integer], desc: 'The group ID or full group path. Must be a top-level group'
          end

          namespace ':id/-/virtual_registries/cleanup/policy' do
            desc 'Get the cleanup policy for a group' do
              detail 'This feature was introduced in GitLab 18.6. \
                This feature is currently in an experimental state. \
                This feature is behind the `maven_virtual_registry` feature flag.'
              success Entities::VirtualRegistries::Cleanup::Policy
              tags %w[virtual_registries_cleanup_policies]
              hidden true
            end

            get do
              present policy, with: Entities::VirtualRegistries::Cleanup::Policy
            end

            desc 'Create a new cleanup policy' do
              detail 'This feature was introduced in GitLab 18.6. \
                This feature is currently in an experimental state. \
                This feature is behind the `maven_virtual_registry` feature flag.'
              success Entities::VirtualRegistries::Cleanup::Policy
              tags %w[virtual_registries_cleanup_policies]
              hidden true
            end

            params do
              with(allow_blank: false) do
                optional :enabled, type: Boolean, desc: 'Boolean to enable/disable the policy'
                optional :keep_n_days_after_download, type: Integer, values: 1..365,
                  desc: 'Number of days after which unused cache entries should be cleaned up'
                optional :cadence, type: Integer, values: ::VirtualRegistries::Cleanup::Policy::CADENCES,
                  desc: 'How often the cleanup policy should run (daily, weekly, monthly, etc.)'
              end
            end

            post do
              policy = ::VirtualRegistries::Cleanup::Policy.new(
                declared_params(include_missing: false).merge(group:)
              )

              render_validation_error!(policy) unless policy.save

              present policy, with: Entities::VirtualRegistries::Cleanup::Policy
            end

            desc 'Update the cleanup policy' do
              detail 'This feature was introduced in GitLab 18.6. \
                This feature is currently in an experimental state. \
                This feature is behind the `maven_virtual_registry` feature flag.'
              success Entities::VirtualRegistries::Cleanup::Policy
              tags %w[virtual_registries_cleanup_policies]
              hidden true
            end

            params do
              with(allow_blank: false) do
                optional :enabled, type: Boolean, desc: 'Boolean to enable/disable the policy'
                optional :keep_n_days_after_download, type: Integer, values: 1..365,
                  desc: 'Number of days after which unused cache entries should be cleaned up'
                optional :cadence, type: Integer, values: ::VirtualRegistries::Cleanup::Policy::CADENCES,
                  desc: 'How often the cleanup policy should run (daily, weekly, monthly, etc.)'
              end
              at_least_one_of :enabled, :keep_n_days_after_download, :cadence
            end

            patch do
              render_validation_error!(policy) unless policy.update(declared_params(include_missing: false))

              present policy, with: Entities::VirtualRegistries::Cleanup::Policy
            end

            desc 'Delete a cleanup policy' do
              detail 'This feature was introduced in GitLab 18.6. \
                This feature is currently in an experimental state. \
                This feature is behind the `maven_virtual_registry` feature flag.'
              tags %w[virtual_registries_cleanup_policies]
              hidden true
            end

            delete do
              destroy_conditionally!(policy)
            end
          end
        end
      end
    end
  end
end
