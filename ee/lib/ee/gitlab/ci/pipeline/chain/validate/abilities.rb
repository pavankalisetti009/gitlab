# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Pipeline
        module Chain
          module Validate
            module Abilities
              extend ::Gitlab::Utils::Override

              override :perform!
              def perform!
                # We check for `builds_enabled?` here so that this error does
                # not get produced before the "pipelines are disabled" error.
                if project.builds_enabled? && mirror_update? && !project.mirror_trigger_builds?
                  return error('Pipeline is disabled for mirror updates')
                end

                super
              end

              private

              def mirror_update?
                # - command.mirror_update is for in-place pipeline creation within pull mirroring.
                # - gitaly_context is for pipelines created from post-receive hooks
                command.mirror_update ||
                  command.gitaly_context&.fetch(::Projects::UpdateMirrorService::GITALY_CONTEXT_KEY, false)
              end

              override :allowed_to_run_pipeline?
              def allowed_to_run_pipeline?
                super || can?(current_user, :create_bot_pipeline, project)
              end
            end
          end
        end
      end
    end
  end
end
