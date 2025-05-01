# frozen_string_literal: true

module API
  module VirtualRegistries
    module Packages
      module Maven
        class RegistryUpstreams < ::API::Base
          include ::API::Concerns::VirtualRegistries::Packages::Maven::SharedSetup

          helpers do
            include ::Gitlab::Utils::StrongMemoize

            delegate :group, :registry, to: :registry_upstream

            alias_method :target_group, :group

            def registry_upstream
              ::VirtualRegistries::Packages::Maven::RegistryUpstream.find(params[:id])
            end
            strong_memoize_attr :registry_upstream
          end

          namespace 'virtual_registries/packages/maven' do
            namespace :registry_upstreams do
              route_param :id, type: Integer, desc: 'The ID of the maven virtual registry upstream' do
                desc 'Update an upstream within a specific maven virtual registry' do
                  detail 'This feature was introduced in GitLab 18.0. \
                      This feature is currently in experiment state. \
                      This feature behind the `virtual_registry_maven` feature flag.'
                  success code: 200
                  failure [
                    { code: 400, message: 'Bad Request' },
                    { code: 401, message: 'Unauthorized' },
                    { code: 403, message: 'Forbidden' },
                    { code: 404, message: 'Not found' }
                  ]
                  tags %w[maven_virtual_registries]
                  hidden true
                end
                params do
                  requires :position, type: Integer, values: 1..20,
                    desc: 'The priority order of an upstream within a maven virtual registry'
                end

                patch do
                  authorize! :update_virtual_registry, registry

                  registry_upstream.update_position(params[:position])

                  status :ok
                end
              end
            end
          end
        end
      end
    end
  end
end
