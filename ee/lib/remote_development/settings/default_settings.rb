# frozen_string_literal: true

module RemoteDevelopment
  module Settings
    class DefaultSettings
      include RemoteDevelopmentConstants

      UNDEFINED = nil

      # When updating DEFAULT_DEVFILE_YAML, update the user facing doc as well.
      # https://docs.gitlab.com/ee/user/workspace/#devfault-devfile
      #
      # The container image is pinned to linux/amd64 digest, instead of the tag digest.
      # This is to prevent Rancher Desktop from pulling the linux/arm64 architecture of the image
      # which will disrupt local development since gitlab-workspaces-tools does not support
      # that architecture yet and thus the workspace won't start.
      # This will be fixed in https://gitlab.com/gitlab-org/workspaces/gitlab-workspaces-tools/-/issues/12
      DEFAULT_DEVFILE_YAML = <<~DEVFILE.freeze
        schemaVersion: #{REQUIRED_DEVFILE_SCHEMA_VERSION}
        components:
          - name: development-environment
            attributes:
              gl/inject-editor: true
            container:
              image: "registry.gitlab.com/gitlab-org/gitlab-build-images/workspaces/ubuntu-24.04:20250109224147-golang-1.23@sha256:c3d5527641bc0c6f4fbbea4bb36fe225b8e9f1df69f682c927941327312bc676"
      DEVFILE

      # ALL REMOTE DEVELOPMENT SETTINGS MUST BE DECLARED HERE.
      # See ../README.md for more details.
      # @return [Hash]
      def self.default_settings
        {
          allow_privilege_escalation: [false, :Boolean],
          annotations: [{}, Hash],
          # NOTE: default_branch_name is not actually used by Remote Development, it is simply a placeholder to drive
          #       the logic for reading settings from ::Gitlab::CurrentSettings. It can be replaced when there is an
          #       actual Remote Development entry in ::Gitlab::CurrentSettings.
          default_branch_name: [UNDEFINED, String],
          default_devfile_yaml: [DEFAULT_DEVFILE_YAML, String],
          default_resources_per_workspace_container: [{}, Hash],
          default_runtime_class: ["", String],
          full_reconciliation_interval_seconds: [3600, Integer],
          gitlab_workspaces_proxy_namespace: ["gitlab-workspaces", String],
          image_pull_secrets: [[], Array],
          labels: [{}, Hash],
          max_active_hours_before_stop: [36, Integer],
          max_resources_per_workspace: [{}, Hash],
          max_stopped_hours_before_termination: [744, Integer],
          network_policy_egress: [[{
            allow: "0.0.0.0/0",
            except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16]
          }], Array],
          network_policy_enabled: [true, :Boolean],
          partial_reconciliation_interval_seconds: [10, Integer],
          project_cloner_image: ["alpine/git:2.45.2", String],
          tools_injector_image: [
            "registry.gitlab.com/gitlab-org/workspaces/gitlab-workspaces-tools:4.0.0", String
          ],
          use_kubernetes_user_namespaces: [false, :Boolean],
          workspaces_per_user_quota: [-1, Integer],
          workspaces_quota: [-1, Integer]
        }
      end
    end
  end
end
