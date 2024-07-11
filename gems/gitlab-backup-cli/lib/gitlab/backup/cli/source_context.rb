# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      # This context is equivalent to a Source Install or GDK instance
      #
      # Any specific information from the GitLab installation will be
      # automatically discovered from the current machine
      class SourceContext
        # Defaults defined in `config/initializers/1_settings.rb`
        DEFAULT_CI_BUILDS_PATH = 'builds/'
        DEFAULT_JOBS_ARTIFACTS_PATH = 'artifacts/'

        def gitlab_version
          File.read(gitlab_basepath.join("VERSION")).strip.freeze
        end

        def backup_basedir
          path = gitlab_config[env]['backup']['path']

          absolute_path(path)
        end

        # CI Builds basepath
        def ci_builds_path
          path = gitlab_config.dig(env, 'gitlab_ci', 'builds_path') || DEFAULT_CI_BUILDS_PATH

          absolute_path(path)
        end

        # Job Artifacts basepath
        def ci_job_artifacts_path
          path = gitlab_config.dig(env, 'artifacts', 'path') ||
            gitlab_config.dig(env, 'artifacts', 'storage_path') ||
            gitlab_shared_path.join(DEFAULT_JOBS_ARTIFACTS_PATH)

          absolute_path(path)
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

        # Return the shared path used as a fallback base location to each blob type
        # We use this to determine the storage location when everything else fails
        # @return [Pathname]
        def gitlab_shared_path
          shared_path = gitlab_config.dig(env, 'shared', 'path')

          return Pathname(shared_path) if shared_path.present?

          raise Gitlab::Backup::Cli::Error,
            "GitLab configuration file: `gitlab.yml` is missing 'shared.path' configuration"
        end

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

        # Return the GitLab base directory
        # @return [Pathname]
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
