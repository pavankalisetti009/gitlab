# frozen_string_literal: true

namespace :gitlab do
  namespace :secrets_management do
    namespace :openbao do
      desc 'GitLab | Secrets Management | Clone and checkout OpenBao'
      task :download_or_clone, [:dir, :repo] => :gitlab_environment do |_, args|
        warn_user_is_not_gitlab

        unless args.dir.present?
          abort %(Please specify the directory where you want to clone OpenBao into
Usage: rake "gitlab:secrets_management:openbao:clone[/installation/dir]")
        end

        args.with_defaults(repo: 'https://gitlab.com/gitlab-org/govern/secrets-management/openbao-internal.git')

        version = SecretsManagement::SecretsManagerClient.expected_server_version
        binary_target_path = "#{args.dir}/bin/bao"

        arch_map = {
          'x86_64' => 'amd64'
        }

        # As per https://gitlab.com/gitlab-org/govern/secrets-management/openbao-internal/-/packages/
        checksums_sha256 = {
          'bao-darwin-arm64' => '59b8268bd0ad841c19954c5719ea32df490c45da518a20ebd97bfaeca4d64dac',
          'bao-darwin-amd64' => 'b575cf2bf2d560572f0b100fa481355cbbaa0bb30077a6acf4648e0c27ee0e74',
          'bao-linux-amd64' => '40b966fb3424f758895794ed30006ca188e55af973729699c17461bb51d09da8'
        }

        os = Gem::Platform.local.os
        arch = Gem::Platform.local.cpu
        arch = arch_map.fetch(arch, arch)

        package_file = "bao-#{os}-#{arch}"

        puts "Downloading binary `#{package_file}` from #{args.repo}"

        downloaded = download_package_file_version(
          version: version,
          repo: args.repo,
          package_name: 'openbao-internal',
          package_file: package_file,
          package_checksums_sha256: checksums_sha256,
          target_path: binary_target_path
        )

        if downloaded
          File.chmod(0o755, binary_target_path)
          # Needed for TestEnv#component_needs_update?
          File.write("#{args.dir}/VERSION", version)
        else
          puts "Checkout from #{args.repo}"

          checkout_or_clone_version(
            version: version,
            repo: args.repo,
            target_dir: args.dir,
            clone_opts: %w[--depth 1 --recurse-submodules]
          )
        end
      end
    end
  end
end
