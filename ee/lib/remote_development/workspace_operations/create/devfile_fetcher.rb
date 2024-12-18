# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class DevfileFetcher
        include Messages

        # NOTE: This method should be called `load` to follow the convention of other singleton methods,
        #       but that naming causes errors due to conflicts with `Kernel#load`.
        #
        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.fetch(context)
          context => { params: Hash => params }
          params => {
            agent: Clusters::Agent => agent,
            project: Project => project,
            devfile_ref: String => devfile_ref,
            devfile_path: String => devfile_path
          }

          unless agent.unversioned_latest_workspaces_agent_config
            return Gitlab::Fp::Result.err(WorkspaceCreateParamsValidationFailed.new(
              details: "No WorkspacesAgentConfig found for agent '#{agent.name}'"
            ))
          end

          repository = project.repository

          devfile_blob = repository.blob_at_branch(devfile_ref, devfile_path)

          unless devfile_blob
            return Gitlab::Fp::Result.err(WorkspaceCreateDevfileLoadFailed.new(
              details: "Devfile path '#{devfile_path}' at ref '#{devfile_ref}' does not exist in project repository"
            ))
          end

          devfile_yaml = devfile_blob.data

          unless devfile_yaml.present?
            return Gitlab::Fp::Result.err(
              WorkspaceCreateDevfileLoadFailed.new(details: "Devfile could not be loaded from project")
            )
          end

          begin
            # load YAML, convert YAML to JSON and load it again to remove YAML vulnerabilities
            devfile_stringified = YAML.safe_load(YAML.safe_load(devfile_yaml).to_json)
            # symbolize keys for domain logic processing of devfile (to_h is to avoid nil dereference error in RubyMine)
            devfile = devfile_stringified.to_h.deep_symbolize_keys
          rescue RuntimeError, JSON::GeneratorError => e
            return Gitlab::Fp::Result.err(WorkspaceCreateDevfileYamlParseFailed.new(
              details: "Devfile YAML could not be parsed: #{e.message}"
            ))
          end

          Gitlab::Fp::Result.ok(context.merge({
            # NOTE: The devfile_yaml should only be used for storing it in the database and not in any other
            #       later step in the chain.
            devfile_yaml: devfile_yaml,
            devfile: devfile
          }))
        end
      end
    end
  end
end
