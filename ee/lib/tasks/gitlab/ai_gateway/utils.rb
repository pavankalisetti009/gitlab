# frozen_string_literal: true

module Tasks
  module Gitlab
    module AiGateway
      module Utils
        REPO_URL = 'https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist.git'
        DEFAULT_BRANCH = 'main'
        DEFAULT_PORT = '50053'

        def self.install!(path:)
          return unless Utils.duo_workflow_service_enabled?
          return unless Utils.prerequisites_met?

          Utils.clone!(path)
          Utils.checkout!(path)
          Utils.install_project_deps!(path)
          Utils.install_runtime_deps!(path)
        end

        def self.run_duo_workflow_service(path:)
          return unless Utils.duo_workflow_service_enabled?
          return unless Utils.prerequisites_met?

          command = %W[poetry -C #{Rails.root.join(path)} run duo-workflow-service]
          command.prepend(*%W[mise -C #{Rails.root.join(path)} exec poetry --]) if Utils.mise_available?

          Process.spawn(
            {
              'AIGW_MOCK_MODEL_RESPONSES' => 'true',
              'AIGW_USE_AGENTIC_MOCK' => 'true',
              'PORT' => Utils.duo_workflow_service_port,
              'DUO_WORKFLOW_AUTH__ENABLED' => 'false',
              'LANGCHAIN_ENDPOINT' => ''
            },
            *command
          )
        end

        def self.latest_sha
          command = %W[#{::Gitlab.config.git.bin_path} ls-remote #{REPO_URL} #{Utils.ai_gateway_repo_branch}]

          out, exit_status = ::Gitlab::Popen.popen(command)

          raise "Failed to fetch the latest SHA of gitlab-ai-gateway: #{out}" unless exit_status == 0

          out.split[0]
        end

        def self.duo_workflow_service_enabled?
          return true if ::Gitlab::Utils.to_boolean(ENV.fetch('TEST_DUO_WORKFLOW_SERVICE_ENABLED', true))

          puts <<~TEXT
            [WARN] Duo Workflow Service is disabled in tests.
                    Some feature tests that depend on it might fail.
          TEXT

          false
        end

        def self.duo_workflow_service_port
          ENV['TEST_DUO_WORKFLOW_SERVICE_PORT'] || DEFAULT_PORT
        end

        def self.ai_gateway_repo_branch
          ENV['TEST_AI_GATEWAY_REPO_BRANCH'] || DEFAULT_BRANCH
        end

        def self.prerequisites_met?
          return true if Utils.mise_available? || Utils.poetry_available?

          puts <<~TEXT
            [WARN] Failed to run Duo Workflow Service or AI Gateway due to missing dependencies.
                   Some feature tests that depend on it might fail.
                   - If you're working on local environment, make sure that you can launch these services in GDK.
                   - If you're working on CI environment, make sure to use a Docker image that has already installed these dependencies.
          TEXT

          false
        end

        def self.poetry_available?
          command = %w[poetry --version]

          begin
            out, exit_status = ::Gitlab::Popen.popen(command)
          rescue Errno::ENOENT => e
            exit_status = -1
            out = e.message
          end

          return true if exit_status == 0

          puts "[INFO] poetry is not available. out: #{out}"
        end

        def self.mise_available?
          command = %w[mise --version]

          begin
            out, exit_status = ::Gitlab::Popen.popen(command)
          rescue Errno::ENOENT => e
            exit_status = -1
            out = e.message
          end

          return true if exit_status == 0

          puts "[INFO] mise is not available. out: #{out}"
        end

        def self.clone!(path)
          command = %W[#{::Gitlab.config.git.bin_path} clone --depth 1 #{REPO_URL} #{path}]

          out, exit_status = ::Gitlab::Popen.popen(command)

          raise "Failed to clone gitlab-ai-gateway repo: #{out}" unless exit_status == 0

          puts "[INFO] Cloned AIGW repository (#{REPO_URL}) at #{path}"
        end

        def self.checkout!(path)
          command = %W[#{::Gitlab.config.git.bin_path} -C #{path} fetch origin
            refs/heads/#{Utils.ai_gateway_repo_branch}:refs/remotes/origin/#{Utils.ai_gateway_repo_branch}]

          out, exit_status = ::Gitlab::Popen.popen(command)

          raise "Failed to fetch gitlab-ai-gateway branch: #{out}" unless exit_status == 0

          command = %W[#{::Gitlab.config.git.bin_path} -C #{path} checkout -B #{Utils.ai_gateway_repo_branch}
            origin/#{Utils.ai_gateway_repo_branch}]

          out, exit_status = ::Gitlab::Popen.popen(command)

          raise "Failed to checkout gitlab-ai-gateway branch: #{out}" unless exit_status == 0

          puts "[INFO] Checked out AIGW repository ref (#{Utils.ai_gateway_repo_branch}) at #{path}"
        end

        def self.install_project_deps!(path)
          return unless Utils.mise_available?

          command = %W[mise -C #{Rails.root.join(path)} install]

          out, exit_status = ::Gitlab::Popen.popen(command)

          raise "Failed to install AIGW project deps: #{out}" unless exit_status == 0

          puts "[INFO] Installed AIGW project deps at #{path}"
        end

        def self.install_runtime_deps!(path)
          command = %W[poetry -C #{Rails.root.join(path)} install]
          command.prepend(*%W[mise -C #{Rails.root.join(path)} exec poetry --]) if Utils.mise_available?

          out, exit_status = ::Gitlab::Popen.popen(command)

          raise "Failed to install AIGW runtime deps: #{out}" unless exit_status == 0

          puts "[INFO] Installed AIGW runtime deps at #{path}"
        end
      end
    end
  end
end
