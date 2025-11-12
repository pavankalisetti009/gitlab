# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    module PipelineHelper
      extend ActiveSupport::Concern

      def ci_auth_path
        [
          full_project_namespace_path,
          'auth',
          ci_auth_mount,
          'login'
        ].compact.join('/')
      end

      def ci_secrets_mount_full_path
        [
          full_project_namespace_path,
          ci_secrets_mount_path
        ].compact.join('/')
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
        %w[pipelines global].compact.join('/')
      end

      def ci_policy_name_env(environment)
        ["pipelines", "env", hex(environment)].compact.join('/')
      end

      def ci_policy_name_branch(branch)
        ["pipelines", "branch", hex(branch)].compact.join('/')
      end

      def ci_policy_name_combined(environment, branch)
        ["pipelines", "combined", "env", hex(environment), "branch", hex(branch)].compact.join('/')
      end

      def ci_auth_literal_policies
        [
          ci_policy_name("*", "*"),
          ci_policy_template_literal_environment,
          ci_policy_template_literal_branch,
          ci_policy_template_literal_combined
        ]
      end

      def ci_policy_template_literal_environment
        "{{ if and (ne nil (index . \"environment\")) (ne \"\" .environment) }}" \
          "pipelines/env/{{ .environment | hex }}{{ end }}"
      end

      def ci_policy_template_literal_branch
        "{{ if and (eq \"branch\" .ref_type) (ne \"\" .ref) }}" \
          "pipelines/branch/{{ .ref | hex }}{{ end }}"
      end

      def ci_policy_template_literal_combined
        "{{ if and (eq \"branch\" .ref_type) (ne nil (index . \"environment\")) (ne \"\" .environment) }}" \
          "pipelines/combined/env/{{ .environment | hex}}/branch/{{ .ref | hex }}{{ end }}"
      end

      def ci_auth_glob_policies(environment, branch)
        ret = []

        ret.append(ci_policy_template_glob_environment(environment)) if environment.include?("*")
        ret.append(ci_policy_template_glob_branch(branch)) if branch.include?("*")

        if environment.include?("*") && branch.include?("*")
          ret.append(ci_policy_template_combined_glob_environment_glob_branch(environment, branch))
        elsif environment.include?("*") && branch.exclude?("*")
          ret.append(ci_policy_template_combined_glob_environment_branch(environment, branch))
        elsif environment.exclude?("*") && branch.include?("*")
          ret.append(ci_policy_template_combined_environment_glob_branch(environment, branch))
        end

        ret
      end

      def ci_policy_template_glob_environment(env_glob)
        # rubocop:disable Layout/LineLength -- expression readability
        env_glob_hex = hex(env_glob)
        "{{ if and (ne nil (index . \"environment\")) (ne \"\" .environment) (eq \"#{env_glob_hex}\" (.environment | hex)) }}" \
          "#{ci_policy_name_env(env_glob)}{{ end }}"
        # rubocop:enable Layout/LineLength
      end

      def ci_policy_template_glob_branch(branch_glob)
        branch_glob_hex = hex(branch_glob)
        "{{ if and (eq \"branch\" .ref_type) (ne \"\" .ref) (eq \"#{branch_glob_hex}\" (.ref | hex)) }}" \
          "#{ci_policy_name_branch(branch_glob)}{{ end }}"
      end

      def ci_policy_template_combined_glob_environment_branch(env_glob, branch_literal)
        # rubocop:disable Layout/LineLength -- expression readability
        env_glob_hex = hex(env_glob)
        "{{ if and (eq \"branch\" .ref_type) (ne \"\" .ref) (ne nil (index . \"environment\")) (ne \"\" .environment) " \
          "(eq \"#{env_glob_hex}\" (.environment | hex)) }}" \
          "#{ci_policy_name_combined(env_glob, branch_literal)}{{ end }}"
        # rubocop:enable Layout/LineLength
      end

      def ci_policy_template_combined_environment_glob_branch(env_literal, branch_glob)
        # rubocop:disable Layout/LineLength -- expression readability
        branch_glob_hex = hex(branch_glob)
        "{{ if and (eq \"branch\" .ref_type) (ne \"\" .ref) (ne nil (index . \"environment\")) (ne \"\" .environment) " \
          "(eq \"#{branch_glob_hex}\" (.ref | hex)) }}" \
          "#{ci_policy_name_combined(env_literal, branch_glob)}{{ end }}"
        # rubocop:enable Layout/LineLength
      end

      def ci_policy_template_combined_glob_environment_glob_branch(env_glob, branch_glob)
        env_glob_hex = hex(env_glob)
        branch_glob_hex = hex(branch_glob)
        "{{ if and (eq \"branch\" .ref_type) (ne \"\" .ref) (ne \"\" .environment) " \
          "(eq \"#{env_glob_hex}\" (.environment | hex)) (eq \"#{branch_glob_hex}\" (.ref | hex)) }}" \
          "#{ci_policy_name_combined(env_glob, branch_glob)}{{ end }}"
      end
    end
  end
end
