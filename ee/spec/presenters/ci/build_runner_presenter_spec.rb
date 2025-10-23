# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::BuildRunnerPresenter, feature_category: :secrets_management do
  subject(:presenter) { described_class.new(ci_build) }

  describe '#secrets_configuration' do
    let!(:ci_build) { create(:ee_ci_build, secrets: secrets, id_tokens: id_tokens) }
    let(:jwt_token) { "TESTING" }
    let(:id_tokens) { nil }

    context 'build has no secrets' do
      let(:secrets) { {} }

      it 'returns empty hash' do
        expect(presenter.secrets_configuration).to eq({})
      end
    end

    context 'build has secrets' do
      context 'with Hashicorp vault' do
        let(:secrets) do
          {
            DATABASE_PASSWORD: {
              file: true,
              vault: {
                engine: { name: 'kv-v2', path: 'kv-v2' },
                path: 'production/db',
                field: 'password'
              }
            }
          }
        end

        before do
          create(:ci_variable, project: ci_build.project, key: 'VAULT_SERVER_URL', value: 'https://vault.example.com')
        end

        context 'Vault server URL' do
          let(:vault_server) { presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'vault', 'server') }

          context 'VAULT_SERVER_URL CI variable is present' do
            it 'returns the URL' do
              expect(vault_server.fetch('url')).to eq('https://vault.example.com')
            end
          end
        end

        context 'Vault auth role' do
          let(:vault_auth_data) do
            presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'vault', 'server', 'auth', 'data')
          end

          context 'VAULT_AUTH_ROLE CI variable is present' do
            it 'contains the auth role' do
              create(:ci_variable, project: ci_build.project, key: 'VAULT_AUTH_ROLE', value: 'production')

              expect(vault_auth_data.fetch('role')).to eq('production')
            end
          end

          context 'VAULT_AUTH_ROLE CI variable is not present' do
            it 'skips the auth role' do
              expect(vault_auth_data).not_to have_key('role')
            end
          end
        end

        context 'Vault auth path' do
          let(:vault_auth) { presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'vault', 'server', 'auth') }

          context 'VAULT_AUTH_PATH CI variable is present' do
            it 'contains user defined auth path' do
              create(:ci_variable, project: ci_build.project, key: 'VAULT_AUTH_PATH', value: 'custom/path')

              expect(vault_auth.fetch('path')).to eq('custom/path')
            end
          end

          context 'VAULT_AUTH_PATH CI variable is not present' do
            it 'contains the default auth path' do
              expect(vault_auth.fetch('path')).to eq('jwt')
            end
          end
        end

        context 'Vault namespace' do
          let(:vault_server) { presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'vault', 'server') }

          context 'VAULT_NAMESPACE CI variable is present' do
            it 'contains user defined namespace' do
              create(:ci_variable, project: ci_build.project, key: 'VAULT_NAMESPACE', value: 'custom_namespace')

              expect(vault_server.fetch('namespace')).to eq('custom_namespace')
            end
          end

          context 'VAULT_NAMESPACE CI variable is not present' do
            it 'returns nil' do
              expect(vault_server.fetch('namespace')).to be_nil
            end
          end
        end

        context 'File variable configuration' do
          subject { presenter.secrets_configuration['DATABASE_PASSWORD'] }

          it 'contains the file configuration directive' do
            expect(subject.fetch('file')).to be_truthy
          end
        end

        context 'when there are ID tokens available' do
          let(:id_tokens) do
            {
              'VAULT_ID_TOKEN_1' => { aud: 'https://gitlab.test' },
              'VAULT_ID_TOKEN_2' => { aud: 'https://gitlab.link' }
            }
          end

          before do
            rsa_key = OpenSSL::PKey::RSA.generate(3072).to_s
            stub_application_setting(ci_jwt_signing_key: rsa_key)
            ci_build.runner = build_stubbed(:ci_runner)
          end

          it 'adds the first ID token to the Vault server payload' do
            jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'vault', 'server', 'auth', 'data', 'jwt')

            expect(jwt).to eq('$VAULT_ID_TOKEN_1')
          end

          context 'when the token variable is specified for the vault secret' do
            let(:secrets) do
              {
                DATABASE_PASSWORD: {
                  file: true,
                  token: '$VAULT_ID_TOKEN_2',
                  vault: {
                    engine: { name: 'kv-v2', path: 'kv-v2' },
                    path: 'production/db',
                    field: 'password'
                  }
                }
              }
            end

            it 'uses the specified token variable' do
              jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'vault', 'server', 'auth', 'data', 'jwt')

              expect(jwt).to eq('$VAULT_ID_TOKEN_2')
            end
          end
        end
      end

      context 'with Azure key vault' do
        let(:secrets) do
          {
            DATABASE_PASSWORD: {
              azure_key_vault: {
                name: 'key',
                version: 'version'
              }
            }
          }
        end

        let(:azure_key_vault_server) do
          presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'azure_key_vault', 'server')
        end

        context 'Vault azure key vault server url' do
          context 'AZURE_KEY_VAULT_SERVER_URL CI variable is present' do
            it 'returns the URL' do
              create(:ci_variable, project: ci_build.project, key: 'AZURE_KEY_VAULT_SERVER_URL', value: 'test')

              expect(azure_key_vault_server.fetch('url')).to eq('test')
            end
          end

          context 'AZURE_KEY_VAULT_SERVER_URL CI variable is not present' do
            it 'returns the nil' do
              expect(azure_key_vault_server.fetch('url')).to eq(nil)
            end
          end
        end

        context 'Vault client id' do
          context 'AZURE_CLIENT_ID CI variable is present' do
            it 'returns the URL' do
              create(:ci_variable, project: ci_build.project, key: 'AZURE_CLIENT_ID', value: 'test')

              expect(azure_key_vault_server.fetch('client_id')).to eq('test')
            end
          end

          context 'AZURE_CLIENT_ID CI variable is not present' do
            it 'returns the nil' do
              expect(azure_key_vault_server.fetch('client_id')).to eq(nil)
            end
          end
        end

        context 'Vault tenant id' do
          context 'AZURE_TENANT_ID CI variable is present' do
            it 'returns the URL' do
              create(:ci_variable, project: ci_build.project, key: 'AZURE_TENANT_ID', value: 'test')

              expect(azure_key_vault_server.fetch('tenant_id')).to eq('test')
            end
          end

          context 'AZURE_TENANT_ID CI variable is not present' do
            it 'returns the nil' do
              expect(azure_key_vault_server.fetch('tenant_id')).to eq(nil)
            end
          end
        end

        context 'when there are ID tokens available' do
          let(:id_tokens) do
            {
              'VAULT_ID_TOKEN_1' => { aud: 'https://gitlab.test' },
              'VAULT_ID_TOKEN_2' => { aud: 'https://gitlab.link' }
            }
          end

          before do
            rsa_key = OpenSSL::PKey::RSA.generate(3072).to_s
            stub_application_setting(ci_jwt_signing_key: rsa_key)
            ci_build.runner = build_stubbed(:ci_runner)
          end

          it 'adds the first ID token to the Vault server payload' do
            jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'azure_key_vault', 'server', 'jwt')
            expect(jwt).to eq('$VAULT_ID_TOKEN_1')
          end

          context 'when the token variable is specified for the vault secret' do
            let(:secrets) do
              {
                DATABASE_PASSWORD: {
                  token: '$VAULT_ID_TOKEN_2',
                  azure_key_vault: {
                    name: 'key',
                    version: 'version'
                  }
                }
              }
            end

            it 'uses the specified token variable' do
              jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'azure_key_vault', 'server', 'jwt')

              expect(jwt).to eq('$VAULT_ID_TOKEN_2')
            end
          end
        end

        context 'when there are no ID tokens available' do
          it 'adds CI_JOB_JWT_V2 to the Vault server payload' do
            jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'azure_key_vault', 'server', 'jwt')

            expect(jwt).to eq('${CI_JOB_JWT_V2}')
          end
        end
      end

      context 'with AWS Secrets Manager' do
        let(:secrets) do
          {
            DATABASE_PASSWORD: {
              aws_secrets_manager: {
                secret_id: 'key',
                version_id: 'version'
              }
            }
          }
        end

        let(:aws_secrets_manager_server) do
          presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'aws_secrets_manager', 'server')
        end

        context 'Secrets Manager Region' do
          context 'AWS_REGION CI variable is present' do
            it 'returns the Region' do
              create(:ci_variable, project: ci_build.project, key: 'AWS_REGION', value: 'test')

              expect(aws_secrets_manager_server.fetch('region')).to eq('test')
            end
          end

          context 'AWS_REGION CI variable is not present' do
            it 'returns the nil' do
              expect(aws_secrets_manager_server.fetch('region')).to eq(nil)
            end
          end
        end

        context 'AWS Role ARN' do
          context 'AWS_ROLE_ARN CI variable is present' do
            it 'returns the Arn' do
              create(:ci_variable, project: ci_build.project, key: 'AWS_ROLE_ARN', value: 'test')

              expect(aws_secrets_manager_server.fetch('role_arn')).to eq('test')
            end
          end

          context 'AWS_ROLE_ARN CI variable is not present' do
            it 'returns the nil' do
              expect(aws_secrets_manager_server.fetch('role_arn')).to eq(nil)
            end
          end
        end

        context 'AWS Role Session Name' do
          context 'AWS_ROLE_SESSION_NAME CI variable is present' do
            it 'returns the Role Session Name' do
              create(:ci_variable, project: ci_build.project, key: 'AWS_ROLE_SESSION_NAME', value: 'test')

              expect(aws_secrets_manager_server.fetch('role_session_name')).to eq('test')
            end
          end

          context 'AWS_ROLE_SESSION_NAME CI variable is not present' do
            it 'returns the nil' do
              expect(aws_secrets_manager_server.fetch('role_session_name')).to eq(nil)
            end
          end
        end

        context 'when there are ID tokens available' do
          let(:id_tokens) do
            {
              'VAULT_ID_TOKEN_2' => { aud: 'https://gitlab.link' },
              'AWS_ID_TOKEN' => { aud: 'https://gitlab.test' }
            }
          end

          before do
            rsa_key = OpenSSL::PKey::RSA.generate(3072).to_s
            stub_application_setting(ci_jwt_signing_key: rsa_key)
            ci_build.runner = build_stubbed(:ci_runner)
          end

          it 'adds the AWS_ID_TOKEN to the Vault server payload' do
            jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'aws_secrets_manager', 'server', 'jwt')

            expect(jwt).to eq('$AWS_ID_TOKEN')
          end

          context 'when the token variable is specified for the vault secret' do
            let(:secrets) do
              {
                DATABASE_PASSWORD: {
                  token: '$VAULT_ID_TOKEN_2',
                  aws_secrets_manager: {
                    secret_id: 'key',
                    version_id: 'version'
                  }
                }
              }
            end

            it 'uses the specified token variable' do
              jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'aws_secrets_manager', 'server', 'jwt')

              expect(jwt).to eq('$VAULT_ID_TOKEN_2')
            end
          end
        end

        context 'when there are no ID tokens available' do
          it 'returns AWS_ID_TOKEN so runner handles the empty variable' do
            jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'aws_secrets_manager', 'server', 'jwt')

            expect(jwt).to eq('$AWS_ID_TOKEN')
          end
        end

        context 'with all AWS configuration variables present' do
          let(:id_tokens) { { 'AWS_ID_TOKEN' => { aud: 'https://aws.example.com' } } }

          before do
            create(:ci_variable, project: ci_build.project, key: 'AWS_REGION', value: 'us-west-2')
            create(:ci_variable, project: ci_build.project, key: 'AWS_ROLE_ARN',
              value: 'arn:aws:iam::123456789012:role/test-role')
            create(:ci_variable, project: ci_build.project, key: 'AWS_ROLE_SESSION_NAME', value: 'gitlab-ci-session')

            rsa_key = OpenSSL::PKey::RSA.generate(3072).to_s
            stub_application_setting(ci_jwt_signing_key: rsa_key)
            ci_build.runner = build_stubbed(:ci_runner)
          end

          it 'returns a complete server configuration' do
            expect(aws_secrets_manager_server).to eq({
              'region' => 'us-west-2',
              'role_arn' => 'arn:aws:iam::123456789012:role/test-role',
              'role_session_name' => 'gitlab-ci-session',
              'jwt' => '$AWS_ID_TOKEN'
            })
          end
        end
      end

      context 'with GCP Secret Manager' do
        let(:secrets) do
          {
            DATABASE_PASSWORD: {
              gcp_secret_manager: {
                name: 'key',
                version: '2'
              },
              token: '$GCP_SM_ID_TOKEN'
            }
          }
        end

        let(:gcp_secret_manager_server) do
          presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'gcp_secret_manager', 'server')
        end

        context 'GCP project number' do
          context 'GCP_PROJECT_NUMBER CI variable is present' do
            it 'returns the value' do
              create(:ci_variable, project: ci_build.project, key: 'GCP_PROJECT_NUMBER', value: '1234')

              expect(gcp_secret_manager_server.fetch('project_number')).to eq('1234')
            end
          end

          context 'GCP_PROJECT_NUMBER CI variable is not present' do
            it 'returns nil' do
              expect(gcp_secret_manager_server.fetch('project_number')).to eq(nil)
            end
          end
        end

        context 'GCP workload federation pool id' do
          context 'GCP_WORKLOAD_IDENTITY_FEDERATION_POOL_ID CI variable is present' do
            it 'returns the pool id' do
              create(:ci_variable, project: ci_build.project, key: 'GCP_WORKLOAD_IDENTITY_FEDERATION_POOL_ID',
                value: 'pool')

              expect(gcp_secret_manager_server.fetch('workload_identity_federation_pool_id')).to eq('pool')
            end
          end

          context 'GCP_WORKLOAD_IDENTITY_FEDERATION_POOL_ID CI variable is not present' do
            it 'returns nil' do
              expect(gcp_secret_manager_server.fetch('workload_identity_federation_pool_id')).to eq(nil)
            end
          end
        end

        context 'GCP workload federation provider id' do
          context 'GCP_WORKLOAD_IDENTITY_FEDERATION_PROVIDER_ID CI variable is present' do
            it 'returns the provider id' do
              create(:ci_variable, project: ci_build.project, key: 'GCP_WORKLOAD_IDENTITY_FEDERATION_PROVIDER_ID',
                value: 'provider')

              expect(gcp_secret_manager_server.fetch('workload_identity_federation_provider_id')).to eq('provider')
            end
          end

          context 'GCP_WORKLOAD_IDENTITY_FEDERATION_PROVIDER_ID CI variable is not present' do
            it 'returns nil' do
              expect(gcp_secret_manager_server.fetch('workload_identity_federation_provider_id')).to eq(nil)
            end
          end
        end

        context 'JWT token' do
          it 'uses the specified token variable' do
            jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'gcp_secret_manager', 'server', 'jwt')

            expect(jwt).to eq('$GCP_SM_ID_TOKEN')
          end
        end
      end

      context 'with Gitlab Secrets Manager' do
        let(:secrets) do
          {
            DATABASE_PASSWORD: {
              gitlab_secrets_manager: {
                name: "password"
              }
            }
          }
        end

        let(:gitlab_secrets_manager_payload) do
          presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'gitlab_secrets_manager')
        end

        let(:gitlab_secrets_manager_server) do
          gitlab_secrets_manager_payload['server']
        end

        let(:project_secrets_manager) do
          SecretsManagement::ProjectSecretsManager.find_by(project: ci_build.project)
        end

        before do
          create(:project_secrets_manager, project: ci_build.project)
          allow_any_instance_of(SecretsManagement::ProjectSecretsManager).to receive(:ci_jwt).and_return(jwt_token) # rubocop:disable RSpec/AnyInstanceOf -- It's not the next instance
        end

        it 'sets the correct values for inline_auth keys' do
          expect(gitlab_secrets_manager_server.fetch('inline_auth')['jwt']).to eq(jwt_token)
          expect(gitlab_secrets_manager_server.fetch('inline_auth')['role']).to eq("all_pipelines")
          expect(gitlab_secrets_manager_server.fetch('inline_auth')['auth_mount']).to eq(project_secrets_manager.ci_auth_mount)
        end

        it 'sets the correct value for the server URL' do
          expect(gitlab_secrets_manager_server.fetch('url')).to eq(SecretsManagement::ProjectSecretsManager.server_url)
        end

        it 'sets the correct value for other fields in the payload' do
          expect(gitlab_secrets_manager_payload.fetch('path')).to eq(project_secrets_manager.ci_data_path('password'))
          expect(gitlab_secrets_manager_payload.fetch('field')).to eq('value')
          expect(gitlab_secrets_manager_payload.fetch('engine')['name']).to eq('kv-v2')
          expect(gitlab_secrets_manager_payload.fetch('engine')['path']).to eq(project_secrets_manager.ci_secrets_mount_path)
        end
      end
    end
  end

  describe '#policy_options' do
    subject(:policy_options) { presenter.policy_options }

    let(:ci_build) { build(:ee_ci_build) }

    context 'when not an execution policy job' do
      it { is_expected.to be_nil }
    end

    context 'when an execution policy job' do
      let(:ci_build) { build(:ee_ci_build, :execution_policy_job) }

      it 'includes policy-specific options' do
        expect(policy_options).to eq(
          execution_policy_job: true,
          policy_name: 'My policy'
        )
      end
    end

    context 'when an execution policy job with variables override' do
      let(:ci_build) { build(:ee_ci_build, :execution_policy_job_with_variables_override) }

      it 'includes policy-specific options' do
        expect(policy_options).to eq(
          execution_policy_job: true,
          policy_name: 'My policy',
          policy_variables_override_allowed: false,
          policy_variables_override_exceptions: ['TEST_VAR']
        )
      end

      context 'when exceptions are empty array' do
        let(:ci_build) do
          build(:ee_ci_build, :execution_policy_job_with_variables_override, variables_override_exceptions: [])
        end

        it 'does not include them in the response' do
          expect(policy_options).to eq(
            execution_policy_job: true,
            policy_name: 'My policy',
            policy_variables_override_allowed: false
          )
        end
      end
    end

    # TODO: Remove with https://gitlab.com/gitlab-org/gitlab/-/issues/577272
    context 'when policy options use an old format' do
      let(:ci_build) do
        build(:ee_ci_build, options: { execution_policy_job: true, execution_policy_name: 'My policy',
                                       execution_policy_variables_override: { allowed: false, exceptions: %w[TEST_VAR] } })
      end

      it 'includes policy-specific options' do
        expect(policy_options).to eq(
          execution_policy_job: true,
          policy_name: 'My policy',
          policy_variables_override_allowed: false,
          policy_variables_override_exceptions: ['TEST_VAR']
        )
      end
    end
  end
end
