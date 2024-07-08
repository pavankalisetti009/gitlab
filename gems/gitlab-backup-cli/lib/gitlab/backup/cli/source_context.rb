# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      # This context is equivalent to a Source Install or GDK instance
      #
      # Any specific information from the GitLab installation will be
      # automatically discovered from the current machine
      class SourceContext
        def gitlab_version
          File.read(gitlab_basepath.join("VERSION")).strip.freeze
        end

        def backup_basedir
          path = gitlab_config[env]['backup']['path']

          absolute_path(path)
        end

        # CI Builds basepath
        def ci_builds_path
          # TODO: Use configuration solver
          Settings.gitlab_ci.builds_path
        end

        # Job Artifacts basepath
        def ci_job_artifacts_path
          # TODO: Use configuration solver
          JobArtifactUploader.root
        end

        # CI Secure Files basepath
        def ci_secure_files_path
          # TODO: Use configuration solver
          Settings.ci_secure_files.storage_path
        end

        # CI LFS basepath
        def ci_lfs_path
          # TODO: Use configuration solver
          Settings.lfs.storage_path
        end

        # Packages basepath
        def packages_path
          # TODO: Use configuration solver
          Settings.packages.storage_path
        end

        # GitLab Pages basepath
        def pages_path
          # TODO: Use configuration solver
          Gitlab.config.pages.path
        end

        # Registry basepath
        def registry_path
          # TODO: Use configuration solver
          Settings.registry.path
        end

        # Terraform State basepath
        def terraform_state_path
          # TODO: Use configuration solver
          Settings.terraform_state.storage_path
        end

        # Upload basepath
        def upload_path
          # TODO: Use configuration solver
          File.join(Gitlab.config.uploads.storage_path, 'uploads')
        end

        def env
          @env ||= ActiveSupport::EnvironmentInquirer.new(
            ENV["RAILS_ENV"].presence || ENV["RACK_ENV"].presence || "development")
        end

        private

        # Return a fullpath for a given path
        #
        # When the path is already a full one return itself as a Pathname
        # otherwise uses gitlab_basepath as its base
        # @param [String|Pathname] path
        # @return [Pathname]
        def absolute_path(path)
          # Joins with gitlab_basepath when relative, otherwise return full path
          Pathname(File.expand_path(path, gitlab_basepath))
        end

        def gitlab_basepath
          return Pathname.new(GITLAB_PATH) if GITLAB_PATH

          raise ::Gitlab::Backup::Cli::Error, 'GITLAB_PATH is missing'
        end

        def gitlab_config
          @gitlab_config ||= Gitlab::Backup::Cli::GitlabConfig.new(gitlab_basepath.join('config/gitlab.yml'))
        end
      end
    end
  end
end
