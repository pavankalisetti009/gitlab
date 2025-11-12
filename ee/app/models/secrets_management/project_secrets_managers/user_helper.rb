# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    module UserHelper
      extend ActiveSupport::Concern

      # User auth CEL program - validates user has access to project
      def user_auth_cel_program(project_id)
        # rubocop:disable Layout/LineLength -- CEL expression readability
        {
          variables: [
            { name: "base", expression: %("users") },
            { name: "uid", expression: %q(('user_id' in claims) ? string(claims['user_id']) : "") },
            { name: "mrid",
              expression: %q(('member_role_id' in claims && claims['member_role_id'] != null) ? string(claims['member_role_id']) : "") },
            { name: "rid", expression: %q(('role_id' in claims) ? string(claims['role_id']) : "") },
            { name: "expected_pid", expression: %("#{project_id}") },
            { name: "pid", expression: %q(('project_id' in claims) ? string(claims['project_id']) : "") },
            { name: "grps", expression: %q(('groups' in claims) ? claims['groups'] : []) },
            { name: "who", expression: %q(uid != "" ? "gitlab-user:" + uid : "gitlab-user:anonymous") },
            { name: "aud", expression: %q(('aud' in claims) ? claims['aud'] : "") },
            { name: "expected_aud", expression: %("#{aud}") },
            { name: "sub", expression: %q(('sub' in claims) ? claims['sub'] : "") },
            { name: "secrets_manager_scope",
              expression: %q(('secrets_manager_scope' in claims) ? string(claims['secrets_manager_scope']) : "") },
            { name: "correlation_id",
              expression: %q(('correlation_id' in claims) ? string(claims['correlation_id']) : "") },
            { name: "namespace_id",
              expression: %q(('namespace_id' in claims) ? string(claims['namespace_id']) : "") }
          ],
          expression: <<~'CEL'.strip
            sub == "" ? "missing subject" :
            !sub.startsWith("user:") ? "invalid subject for user authentication" :
            secrets_manager_scope == "" ? "missing secrets_manager_scope" :
            secrets_manager_scope != "user" ? "invalid secrets_manager_scope" :
            pid == "" ? "missing project_id" :
            pid != expected_pid ? "token project_id does not match role base" :
            aud == "" ? "missing audience" :
            aud != expected_aud ? "audience validation failed" :
            uid == "" ? "missing user_id" :
            pb.Auth{
              display_name: who,
              alias: logical.Alias { name: who },
              policies:
                (uid  != "" ? [base + "/direct/user_"        + uid]  : []) +
                (mrid != "" ? [base + "/direct/member_role_" + mrid] : []) +
                grps.map(g, base + "/direct/group_" + string(g)) +
                (rid  != "" ? [base + "/roles/"              + rid]  : []),
              metadata: {
                "correlation_id": correlation_id,
                "project_id": pid,
                "namespace_id": namespace_id,
                "user_id": uid
              }
            }
          CEL
        }
        # rubocop:enable Layout/LineLength
      end
    end
  end
end
