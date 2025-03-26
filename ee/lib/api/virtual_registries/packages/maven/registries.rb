# frozen_string_literal: true

module API
  module VirtualRegistries
    module Packages
      module Maven
        class Registries < ::API::Base
          include ::API::Concerns::VirtualRegistries::Packages::Maven::SharedSetup

          helpers do
            include ::Gitlab::Utils::StrongMemoize

            def target_group
              request.path.include?('/groups') ? group : registry.group
            end

            def group
              find_group!(params[:id])
            end
            strong_memoize_attr :group

            def registry
              ::VirtualRegistries::Packages::Maven::Registry.find(params[:id])
            end
            strong_memoize_attr :registry

            def policy_subject
              group.virtual_registry_policy_subject
            end
          end

          resource :groups, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
            params do
              requires :id, types: [String, Integer], desc: 'The group ID or full group path. Must be a top-level group'
            end

            namespace ':id/-/virtual_registries/packages/maven/registries' do
              desc 'Get the list of all maven virtual registries' do
                detail 'This feature was introduced in GitLab 17.4. \
                    This feature is currently in an experimental state. \
                    This feature is behind the `virtual_registry_maven` feature flag.'
                success ::API::Entities::VirtualRegistries::Packages::Maven::Registry
                failure [
                  { code: 400, message: 'Bad Request' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 403, message: 'Forbidden' },
                  { code: 404, message: 'Not found' }
                ]
                tags %w[maven_virtual_registries]
                hidden true
              end

              get do
                authorize! :read_virtual_registry, policy_subject

                registries = ::VirtualRegistries::Packages::Maven::Registry.for_group(group)

                present registries, with: ::API::Entities::VirtualRegistries::Packages::Maven::Registry
              end

              desc 'Create a new maven virtual registry' do
                detail 'This feature was introduced in GitLab 17.4. \
                    This feature is currently in an experimental state. \
                    This feature is behind the `virtual_registry_maven` feature flag.'
                success ::API::Entities::VirtualRegistries::Packages::Maven::Registry
                failure [
                  { code: 400, message: 'Bad request' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 403, message: 'Forbidden' },
                  { code: 404, message: 'Not found' }
                ]
                tags %w[maven_virtual_registries]
                hidden true
              end

              post do
                authorize! :create_virtual_registry, policy_subject

                new_reg = ::VirtualRegistries::Packages::Maven::Registry.new(group:)

                render_validation_error!(new_reg) unless new_reg.save

                present new_reg, with: ::API::Entities::VirtualRegistries::Packages::Maven::Registry
              end
            end
          end

          namespace 'virtual_registries/packages/maven/registries' do
            route_param :id, type: Integer, desc: 'The ID of the maven virtual registry' do
              desc 'Get a specific maven virtual registry' do
                detail 'This feature was introduced in GitLab 17.4. \
                  This feature is currently in an experimental state. \
                  This feature is behind the `virtual_registry_maven` feature flag.'
                success ::API::Entities::VirtualRegistries::Packages::Maven::Registry
                failure [
                  { code: 400, message: 'Bad request' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 403, message: 'Forbidden' },
                  { code: 404, message: 'Not found' }
                ]
                tags %w[maven_virtual_registries]
                hidden true
              end
              get do
                authorize! :read_virtual_registry, registry

                present registry, with: ::API::Entities::VirtualRegistries::Packages::Maven::Registry
              end

              desc 'Delete a specific maven virtual registry' do
                detail 'This feature was introduced in GitLab 17.4. \
                  This feature is currently in an experimental state. \
                  This feature is behind the `virtual_registry_maven` feature flag.'
                success code: 204
                failure [
                  { code: 400, message: 'Bad request' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 403, message: 'Forbidden' },
                  { code: 404, message: 'Not found' },
                  { code: 412, message: 'Precondition Failed' }
                ]
                tags %w[maven_virtual_registries]
                hidden true
              end
              delete do
                authorize! :destroy_virtual_registry, registry

                destroy_conditionally!(registry)
              end
            end
          end
        end
      end
    end
  end
end
