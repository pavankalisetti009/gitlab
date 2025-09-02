# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class CreatorBootstrapper
        include CreateConstants

        RANDOM_STRING_LENGTH = 6

        # @param [Hash] context
        # @return [Hash]
        def self.bootstrap(context)
          # Skip type checking so we can use fast_spec_helper in the unit test spec
          context => {
            params: {
              agent: agent
            }
          }

          workspace_name_prefix = "workspace"
          workspace_name_suffix = generate_unique_workspace_suffix(workspace_name_prefix)
          workspace_name = "#{workspace_name_prefix}-#{workspace_name_suffix}"
          shared_namespace = agent.unversioned_latest_workspaces_agent_config.shared_namespace

          workspace_namespace =
            # NOTE: Empty string is a "magic value" that indicates default per-workspace namespaces should be used.
            case shared_namespace
            when ""
              # Use a unique namespace, with one workspace per namespace
              "#{NAMESPACE_PREFIX}-#{workspace_name_suffix}"
            else
              # Use a shared namespace, with multiple workspaces in the same namespace
              shared_namespace
            end

          context.merge(
            workspace_name: workspace_name,
            workspace_namespace: workspace_namespace
          )
        end

        # @param [String] workspace_name_prefix - This is required to ensure uniqueness
        # @return [String]
        def self.generate_unique_workspace_suffix(workspace_name_prefix)
          max_retries = 30

          max_retries.times do |_|
            workspace_name_suffix = [
              FFaker::Food.fruit,
              FFaker::AnimalUS.common_name,
              FFaker::Color.name
            ].map(&:downcase)
             .map(&:parameterize)
             .join("-")

            workspace_name = [workspace_name_prefix, workspace_name_suffix].join("-")

            unless workspace_name.length > 64 || RemoteDevelopment::Workspace.by_names(workspace_name).exists?
              return workspace_name_suffix
            end
          end

          raise "Unable to generate unique workspace name after #{max_retries} attempts"
        end

        private_class_method :generate_unique_workspace_suffix
      end
    end
  end
end
