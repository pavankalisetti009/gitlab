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
          'bao-darwin-amd64' => 'c22a5dac934ca5b68b5d97066f53fbb82e1d3cb621fedd999809d9553f5dafa8',
          'bao-darwin-arm64' => 'a36137759e03d6b1bf919d92724267259ba50b92c10ef475062f92c07b179e72',
          'bao-linux-amd64' => '4746f8e0d68f532f0b7504f5357241fb30cf64f157e8c7a2928039fa33ce8d27',
          'bao-linux-arm64' => '873ac68297628b24d7b8f32c654cf67553e7e87937ba351022156afc948ab855'
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
