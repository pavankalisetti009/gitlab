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
          'aarch64' => 'arm64',
          'x86_64' => 'amd64'
        }

        # As per https://gitlab.com/gitlab-org/govern/secrets-management/openbao-internal/-/packages/
        checksums_sha256 = {
          'bao-darwin-amd64' => '86914895e4abc5e15956464ade560230441f8fc2b9cf01918d8c9a89983858e3',
          'bao-darwin-arm64' => 'b0e54f3846ef9239ca90bff174c02422a8782fe71e1cc49508c68c8edd037ca4',
          'bao-linux-amd64' => 'ce2fe19446b7467bb229138e46f9d37d7cdc8b6f8440cc83b6378bdc8e60553d',
          'bao-linux-arm64' => '905b708555f792751586a1f145cae6ecd62ba8c7c22bab9407da8016a933de8c'
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
            clone_opts: %w[--depth 1 --recurse-submodules],
            checkout_opts: %w[--recurse-submodules]
          )
        end
      end

      desc 'GitLab | Secrets Management | Retrieve recovery keys from OpenBao'
      task :recovery_key_retrieve, [] => :gitlab_environment do
        privileged_jwt = SecretsManagement::SecretsManagerJwt.new.encoded
        secrets_manager_client = SecretsManagement::SecretsManagerClient.new(jwt: privileged_jwt)

        result = secrets_manager_client.init_rotate_recovery
        if result["data"].key? "keys"
          key = result["data"]["keys"][0]

          old_key = SecretsManagement::RecoveryKey.active.take
          if old_key
            old_key.active = false
            old_key.save!
            puts "Marked old key as inactive."
          end

          # Store key, and then mark it as active. This way, the key is
          # persisted even if there's some error when trying to make it the
          # only active key.
          new_key = SecretsManagement::RecoveryKey.new do |nk|
            nk.active = false
            nk.key = key
          end
          new_key.save!

          puts "Persisted key to the database."

          new_key.active = true
          new_key.save!

          puts "Marked key as active."

          new_key
        else
          puts "Cannot get key, key has already been retrieved."

          # Avoid leaving rotation in an inconsistent state.
          secrets_manager_client.cancel_rotate_recovery

          nil
        end
      rescue SecretsManagement::SecretsManagerClient::ApiError => e
        puts "Cannot get key, exception: #{e}"
        Gitlab::ErrorTracking.track_and_raise_exception(e)
      end
    end
  end
end
