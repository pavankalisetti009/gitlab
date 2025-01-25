# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Config
        module External
          module File
            module Project
              extend ::Gitlab::Utils::Override

              private

              override :project_access_allowed?
              def project_access_allowed?(user, project)
                super || security_policy_management_project_access_allowed?(user, project)
              end

              def security_policy_management_project_access_allowed?(user, project)
                unless context.pipeline_config&.pipeline_policy_context&.policy_management_project_access_allowed?
                  return false
                end

                return false unless context.project.affected_by_security_policy_management_project?(project)

                Ability.allowed?(user, :download_code_spp_repository, project)
              end
            end
          end
        end
      end
    end
  end
end
