# frozen_string_literal: true

module SecretsManagement
  class ProjectSecretsManager < ApplicationRecord
    include Gitlab::InternalEventsTracking
    include ProjectSecretsManagers::UserHelper

    STATUSES = {
      provisioning: 0,
      active: 1,
      deprovisioning: 2
    }.freeze

    self.table_name = 'project_secrets_managers'

    belongs_to :project, inverse_of: :secrets_manager

    validates :project, presence: true

    state_machine :status, initial: :provisioning do
      state :provisioning, value: STATUSES[:provisioning]
      state :active, value: STATUSES[:active]
      state :deprovisioning, value: STATUSES[:deprovisioning]

      event :activate do
        transition all - [:active] => :active
      end

      event :initiate_deprovision do
        transition active: :deprovisioning
      end
    end

    def self.jwt_issuer
      Gitlab.config.gitlab.base_url
    end

    def self.internal_server_url
      # Gitlab.com deployment configuration
      if Gitlab.config.has_key?("openbao") && Gitlab.config.openbao.has_key?("internal_url")
        return Gitlab.config.openbao.internal_url
      end

      server_url
    end

    def self.server_url
      return SecretsManagement::OpenbaoTestSetup::SERVER_ADDRESS_WITH_HTTP if Rails.env.test?
      # Gitlab.com deployment configuration
      return Gitlab.config.openbao.url if Gitlab.config.has_key?("openbao") && Gitlab.config.openbao.has_key?("url")

      # Local configuration
      default_openbao_server_url
    end

    def self.default_openbao_server_url
      "#{Gitlab.config.gitlab.protocol}://#{Gitlab.config.gitlab.host}:8200"
    end
    private_class_method :default_openbao_server_url

    def ci_secrets_mount_path
      %w[
        secrets
        kv
      ].compact.join('/')
    end

    def legacy_ci_secrets_mount_path
      [
        full_project_namespace_path,
        ci_secrets_mount_path
      ].compact.join('/')
    end

    def ci_data_root_path
      'explicit'
    end

    def ci_data_path(secret_key = nil)
      [
        ci_data_root_path,
        secret_key
      ].compact.join('/')
    end

    def ci_full_path(secret_key)
      [
        ci_secrets_mount_path,
        'data',
        ci_data_path(secret_key)
      ].compact.join('/')
    end

    def ci_metadata_full_path(secret_key)
      [
        ci_secrets_mount_path,
        'metadata',
        ci_data_path(secret_key)
      ].compact.join('/')
    end

    def detailed_metadata_path(secret_key)
      [
        ci_secrets_mount_path,
        'detailed-metadata',
        ci_data_path(secret_key)
      ].compact.join('/')
    end

    def ci_auth_mount
      [
        'pipeline_jwt'
      ].compact.join('/')
    end

    def legacy_ci_auth_mount
      [
        full_project_namespace_path,
        ci_auth_mount
      ].compact.join('/')
    end

    def ci_auth_path
      [
        full_project_namespace_path,
        'auth',
        ci_auth_mount,
        'login'
      ].compact.join('/')
    end

    def legacy_user_auth_mount
      [
        full_project_namespace_path,
        "user_jwt"
      ].compact.join('/')
    end

    def ci_auth_role
      "all_pipelines"
    end

    def legacy_ci_auth_role
      "project_#{project.id}"
    end

    def ci_auth_type
      'jwt'
    end

    def ci_jwt(build)
      track_ci_jwt_generation(build)
      SecretsManagement::PipelineJwt.for_build(build, aud: aud)
    end

    def ci_policy_name(environment, branch)
      if environment != "*" && branch != "*"
        ci_policy_name_combined(environment, branch)
      elsif environment != "*"
        ci_policy_name_env(environment)
      elsif branch != "*"
        ci_policy_name_branch(branch)
      else
        ci_policy_name_global
      end
    end

    def ci_policy_name_global
      %w[
        pipelines
        global
      ].compact.join('/')
    end

    def ci_policy_name_env(environment)
      [
        "pipelines",
        "env",
        environment.unpack1('H*')
      ].compact.join('/')
    end

    def ci_policy_name_branch(branch)
      [
        "pipelines",
        "branch",
        branch.unpack1('H*')
      ].compact.join('/')
    end

    def ci_policy_name_combined(environment, branch)
      [
        "pipelines",
        "combined",
        "env",
        environment.unpack1('H*'),
        "branch",
        branch.unpack1('H*')
      ].compact.join('/')
    end

    def ci_auth_literal_policies
      [
        # Global policy
        ci_policy_name("*", "*"),
        # Environment policy
        ci_policy_template_literal_environment,
        # Branch policy
        ci_policy_template_literal_branch,
        # Combined environment+branch policy
        ci_policy_template_literal_combined
      ]
    end

    def ci_policy_template_literal_environment
      "{{ if and (ne nil (index . \"environment\")) (ne \"\" .environment) }}" \
        "pipelines/env/{{ .environment | hex }}{{ end }}"
    end

    def ci_policy_template_literal_branch
      "{{ if and (eq \"branch\" .ref_type) (ne \"\" .ref) }}" \
        "pipelines/" \
        "branch/{{ .ref | hex }}" \
        "{{ end }}"
    end

    def ci_policy_template_literal_combined
      "{{ if and (eq \"branch\" .ref_type) (ne nil (index . \"environment\")) (ne \"\" .environment) }}" \
        "pipelines/combined/" \
        "env/{{ .environment | hex}}/" \
        "branch/{{ .ref | hex }}" \
        "{{ end }}"
    end

    def ci_auth_glob_policies(environment, branch)
      ret = []

      # Add environment or branch policies. Both may be added.
      ret.append(ci_policy_template_glob_environment(environment)) if environment.include?("*")
      ret.append(ci_policy_template_glob_branch(branch)) if branch.include?("*")

      # Add the relevant combined policy. Only one will be added.
      if environment.include?("*") && branch.include?("*")
        ret.append(ci_policy_template_combined_glob_environment_glob_branch(environment,
          branch))
      end

      if environment.include?("*") && branch.exclude?("*")
        ret.append(ci_policy_template_combined_glob_environment_branch(environment,
          branch))
      end

      if environment.exclude?("*") && branch.include?("*")
        ret.append(ci_policy_template_combined_environment_glob_branch(environment,
          branch))
      end

      ret
    end

    def ci_policy_template_glob_environment(env_glob)
      # Because env_glob is converted to hex, we know it is safe to
      # directly embed in the template string. This is a bit more expensive
      # to evaluate but saves us from having to ensure we always have
      # consistent string escaping for text/template.
      env_glob_hex = env_glob.unpack1('H*')
      "{{ if and " \
        "(ne nil (index . \"environment\")) " \
        "(ne \"\" .environment) " \
        "(eq \"#{env_glob_hex}\" (.environment | hex)) }}" \
        "#{ci_policy_name_env(env_glob)}" \
        "{{end }}"
    end

    def ci_policy_template_glob_branch(branch_glob)
      # See note in ci_policy_template_glob_environment.
      branch_glob_hex = branch_glob.unpack1('H*')

      "{{ if and (eq \"branch\" .ref_type) (ne \"\" .ref) (eq \"#{branch_glob_hex}\" (.ref | hex)) }}" \
        "#{ci_policy_name_branch(branch_glob)}" \
        "{{ end }}"
    end

    def ci_policy_template_combined_glob_environment_branch(env_glob, branch_literal)
      # See note in ci_policy_template_glob_environment.
      env_glob_hex = env_glob.unpack1('H*')
      "{{ if and " \
        "(eq \"branch\" .ref_type) " \
        "(ne \"\" .ref) " \
        "(ne nil (index . \"environment\")) " \
        "(ne \"\" .environment) " \
        "(eq \"#{env_glob_hex}\" (.environment | hex)) }}" \
        "#{ci_policy_name_combined(env_glob, branch_literal)}" \
        "{{ end }}"
    end

    def ci_policy_template_combined_environment_glob_branch(env_literal, branch_glob)
      # See note in ci_policy_template_glob_environment.
      branch_glob_hex = branch_glob.unpack1('H*')
      "{{ if and " \
        "(eq \"branch\" .ref_type) " \
        "(ne \"\" .ref) " \
        "(ne nil (index . \"environment\")) " \
        "(ne \"\" .environment) " \
        "(eq \"#{branch_glob_hex}\" (.ref | hex)) }}" \
        "#{ci_policy_name_combined(env_literal, branch_glob)}" \
        "{{ end }}"
    end

    def ci_policy_template_combined_glob_environment_glob_branch(env_glob, branch_glob)
      # See note in ci_policy_template_glob_environment.
      env_glob_hex = env_glob.unpack1('H*')
      branch_glob_hex = branch_glob.unpack1('H*')
      "{{ if and " \
        "(eq \"branch\" .ref_type) " \
        "(ne \"\" .ref) " \
        "(ne nil (index . \"environment\")) " \
        "(ne \"\" .environment) " \
        "(eq \"#{env_glob_hex}\" (.environment | hex)) " \
        "(eq \"#{branch_glob_hex}\" (.ref | hex)) }}" \
        "#{ci_policy_name_combined(env_glob, branch_glob)}" \
        "{{ end }}"
    end

    def user_path
      %w[
        users
        direct
      ].compact.join('/')
    end

    def role_path
      %w[
        users
        roles
      ].compact.join('/')
    end

    def generate_policy_name(principal_type:, principal_id:)
      case principal_type
      when 'User'
        [
          user_path,
          "user_#{principal_id}"
        ].compact.join('/')
      when 'Role'
        [
          role_path,
          principal_id
        ].compact.join('/')
      when 'MemberRole'
        [
          user_path,
          "member_role_#{principal_id}"
        ].compact.join('/')
      when 'Group'
        [
          user_path,
          "group_#{principal_id}"
        ].compact.join('/')
      end
    end

    def user_auth_cel_program(project_id)
      {
        variables: [
          { name: "base",  expression: %("users") },
          { name: "uid",   expression: %q(('user_id' in claims) ? string(claims['user_id']) : "") },
          { name: "mrid",
            expression: %q(('member_role_id' in claims && claims['member_role_id'] != null) ?
                            string(claims['member_role_id']) : "") },
          { name: "rid", expression: %q(('role_id' in claims) ? string(claims['role_id']) : "") },
          { name: "expected_pid", expression: %("#{project_id}") },
          { name: "pid",   expression: %q(('project_id' in claims) ? string(claims['project_id']) : "") },
          { name: "grps",  expression: %q(('groups' in claims) ? claims['groups'] : []) },
          { name: "who",   expression: %q(uid != "" ? "gitlab-user:" + uid : "gitlab-user:anonymous") },
          { name: "aud",   expression: %q(('aud' in claims) ? claims['aud'] : "") },
          { name: "expected_aud", expression: %("#{aud}") },
          { name: "sub", expression: %q(('sub' in claims) ? claims['sub'] : "") },
          { name: "secrets_manager_scope",
            expression: %q(('secrets_manager_scope' in claims) ? string(claims['secrets_manager_scope']) : "") },
          # Add metadata variables
          {
            name: "correlation_id",
            expression: %q(('correlation_id' in claims) ? string(claims['correlation_id']) : "")
          },
          {
            name: "namespace_id",
            expression: %q(('namespace_id' in claims) ? string(claims['namespace_id']) : "")
          }
        ],
        expression: <<~'CEL'.strip
          pid == "" ? "missing project_id" :
          pid != expected_pid ? "token project_id does not match role base" :
          aud == "" ? "missing audience" :
          aud != expected_aud ? "audience validation failed" :
          sub == "" ? "missing subject" :
          !sub.startsWith("user:") ? "invalid subject for user authentication" :
          secrets_manager_scope == "" ? "missing secrets_manager_scope" :
          secrets_manager_scope != "user" ? "invalid secrets_manager_scope" :
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
    end

    def namespace_path
      [
        project.namespace.type.downcase,
        project.namespace.id.to_s
      ].join('_')
    end

    def project_path
      "project_#{project.id}"
    end

    def full_project_namespace_path
      [
        namespace_path,
        project_path
      ].compact.join('/')
    end

    private

    def track_ci_jwt_generation(build)
      track_internal_event(
        'generate_id_token_for_secrets_manager_authentication',
        project: project,
        namespace: project.namespace,
        user: build.user
      )
    end

    def aud
      self.class.server_url
    end
  end
end
