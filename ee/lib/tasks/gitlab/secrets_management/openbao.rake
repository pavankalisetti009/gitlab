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
          'bao-darwin-arm64' => '67df73725c198cf3387b73e97829d1a2c58c7af07ba5f3e15b052a0fe20a1086',
          'bao-darwin-amd64' => '88d8bff43ebcbaa5cfb158d61c0a3d6c69ca8a9f8f2ce20375f4e61cee985f43',
          'bao-linux-amd64' => 'c128027272ed973486ded9e2b9d1bef0fa72324e67878bdd5ab47c16128ce245'
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
