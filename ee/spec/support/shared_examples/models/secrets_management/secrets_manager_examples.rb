# frozen_string_literal: true

RSpec.shared_examples 'a secrets manager' do
  describe 'state machine' do
    context 'when newly created' do
      it 'defaults to provisioning' do
        expect(secrets_manager).to be_provisioning
      end
    end

    context 'when activating' do
      it 'allows transitions from any non-active status to active' do
        [:provisioning, :deprovisioning].each do |status|
          secrets_manager.update!(status: secrets_manager.class::STATUSES[status])
          expect { secrets_manager.activate! }
            .to change { secrets_manager.reload.status }
            .from(described_class::STATUSES[status])
            .to(described_class::STATUSES[:active])
        end
      end

      it 'cannot transition from active to active' do
        secrets_manager.activate!
        expect(secrets_manager).to be_active

        expect { secrets_manager.activate! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end

    context 'when initiating deprovisioning' do
      it 'transitions from active to deprovisioning' do
        secrets_manager.activate!

        expect { secrets_manager.initiate_deprovision! }
          .to change { secrets_manager.reload.status }
          .from(described_class::STATUSES[:active])
          .to(described_class::STATUSES[:deprovisioning])
      end

      it 'cannot transition from non-active states' do
        [:provisioning, :deprovisioning].each do |status|
          secrets_manager.update!(status: secrets_manager.class::STATUSES[status])
          expect { secrets_manager.initiate_deprovision! }
            .to raise_error(StateMachines::InvalidTransition)
        end
      end
    end
  end

  describe 'pipeline helper methods' do
    describe '#ci_secrets_mount_path' do
      it 'returns the correct mount path' do
        expect(secrets_manager.ci_secrets_mount_path).to eq("secrets/kv")
      end
    end

    describe '#ci_data_path' do
      it 'returns the correct data path without namespace information' do
        expect(secrets_manager.ci_data_path("DB_PASS")).to eq("explicit/DB_PASS")
      end

      it 'handles nil secret key' do
        expect(secrets_manager.ci_data_path(nil)).to eq("explicit")
      end
    end

    describe '#ci_full_path' do
      it 'returns the correct full path without namespace information' do
        expect(secrets_manager.ci_full_path("DB_PASS")).to eq("secrets/kv/data/explicit/DB_PASS")
      end
    end

    describe '#ci_metadata_full_path' do
      it 'returns the correct metadata path' do
        expect(secrets_manager.ci_metadata_full_path("DB_PASS")).to eq("secrets/kv/metadata/explicit/DB_PASS")
      end
    end

    describe '#detailed_metadata_path' do
      it 'returns the correct detailed metadata path' do
        expect(secrets_manager.detailed_metadata_path("DB_PASS")).to eq("secrets/kv/detailed-metadata/explicit/DB_PASS")
      end
    end

    describe '#ci_auth_mount' do
      it 'returns pipeline_jwt' do
        expect(secrets_manager.ci_auth_mount).to eq('pipeline_jwt')
      end
    end

    describe '#ci_auth_role' do
      it 'returns all_pipelines' do
        expect(secrets_manager.ci_auth_role).to eq('all_pipelines')
      end
    end

    describe '#ci_auth_type' do
      it 'returns jwt' do
        expect(secrets_manager.ci_auth_type).to eq('jwt')
      end
    end

    describe '#ci_jwt' do
      let_it_be(:build_project) { create(:project) }
      let_it_be(:ci_build) { create(:ci_build, project: build_project) }
      let_it_be(:openbao_server_url) { described_class.server_url }

      subject(:ci_jwt) { secrets_manager.ci_jwt(ci_build) }

      before do
        allow(SecretsManagement::PipelineJwt).to receive(:for_build)
          .with(ci_build, aud: openbao_server_url)
          .and_return("generated_jwt_id_token_for_secrets_manager")
      end

      it 'generates a JWT for the build' do
        expect(ci_jwt).to eq("generated_jwt_id_token_for_secrets_manager")
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'generate_id_token_for_secrets_manager_authentication' }
        let(:category) { described_class.name }
        let(:project) { build_project }
        let(:namespace) { build_project.namespace }
        let(:user) { ci_build.user }
      end
    end
  end

  describe 'user helper methods' do
    describe '#user_auth_mount' do
      it 'returns user_jwt' do
        expect(secrets_manager.user_auth_mount).to eq('user_jwt')
      end
    end

    describe '#user_auth_role' do
      it 'returns all_users' do
        expect(secrets_manager.user_auth_role).to eq('all_users')
      end
    end

    describe '#user_auth_type' do
      it 'returns jwt' do
        expect(secrets_manager.user_auth_type).to eq('jwt')
      end
    end

    describe '#policy_name_for_principal' do
      subject(:policy_name) do
        secrets_manager.send(:policy_name_for_principal, principal_type: principal_type, principal_id: principal_id)
      end

      context 'for User principal type' do
        let(:principal_type) { 'User' }
        let(:principal_id) { 123 }

        it 'generates the correct policy name' do
          expect(policy_name).to eq("users/direct/user_123")
        end
      end

      context 'for Role principal type' do
        let(:principal_type) { 'Role' }
        let(:principal_id) { 3 }

        it 'generates the correct policy name with role ID' do
          expect(policy_name).to eq("users/roles/3")
        end
      end

      context 'for MemberRole principal type' do
        let(:principal_type) { 'MemberRole' }
        let(:principal_id) { 3 }

        it 'generates the correct policy name with member role ID' do
          expect(policy_name).to eq("users/direct/member_role_3")
        end
      end

      context 'for Group principal type' do
        let(:principal_type) { 'Group' }
        let(:principal_id) { 3 }

        it 'generates the correct policy name with group ID' do
          expect(policy_name).to eq("users/direct/group_3")
        end
      end
    end

    describe '#user_path' do
      it 'returns the correct user path' do
        expect(secrets_manager.send(:user_path)).to eq('users/direct')
      end
    end

    describe '#role_path' do
      it 'returns the correct role path' do
        expect(secrets_manager.send(:role_path)).to eq('users/roles')
      end
    end
  end

  describe 'server configuration' do
    describe '.server_url' do
      before do
        # Bypass check for Rails.env.test? that would otherwise force return the test server URL
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      context 'when openbao is configured with url' do
        before do
          allow(Gitlab.config).to receive(:has_key?).with('openbao').and_return(true)
          allow(Gitlab.config).to receive(:openbao).and_return(
            GitlabSettings::Options.build(url: 'http://openbao-external:8200')
          )
        end

        it 'returns the configured url' do
          expect(secrets_manager.class.server_url).to eq('http://openbao-external:8200')
        end
      end

      context 'when openbao is not configured' do
        before do
          allow(Gitlab.config).to receive(:has_key?).with('openbao').and_return(false)
        end

        it 'returns the default url' do
          expect(secrets_manager.class.server_url).to eq('http://localhost:8200')
        end
      end

      context 'when openbao is configured but url is nil' do
        before do
          allow(Gitlab.config).to receive(:has_key?).with('openbao').and_return(true)
          allow(Gitlab.config).to receive(:openbao).and_return(
            GitlabSettings::Options.build(internal_url: 'http://openbao-internal:8200')
          )
        end

        it 'returns the default url' do
          expect(secrets_manager.class.server_url).to eq('http://localhost:8200')
        end
      end
    end

    describe '.internal_server_url' do
      before do
        # Bypass check for Rails.env.test? that would otherwise force return the test server URL
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      context 'when internal_url is configured' do
        before do
          allow(Gitlab.config).to receive(:has_key?).with('openbao').and_return(true)
          allow(Gitlab.config).to receive(:openbao).and_return(
            GitlabSettings::Options.build(internal_url: 'http://openbao-internal:8200')
          )
        end

        it 'returns the internal_url' do
          expect(secrets_manager.class.internal_server_url).to eq('http://openbao-internal:8200')
        end
      end

      context 'when openbao is configured but internal_url is not' do
        before do
          allow(Gitlab.config).to receive(:has_key?).with('openbao').and_return(true)
          allow(Gitlab.config).to receive(:openbao).and_return(
            GitlabSettings::Options.build(url: 'http://openbao-external:8200')
          )
        end

        it 'falls back to server_url' do
          expect(secrets_manager.class.internal_server_url).to eq('http://openbao-external:8200')
        end
      end

      context 'when openbao is not configured' do
        before do
          allow(Gitlab.config).to receive(:has_key?).with('openbao').and_return(false)
          allow(secrets_manager.class).to receive(:server_url).and_return('http://localhost:8200')
        end

        it 'falls back to server_url' do
          expect(secrets_manager.class.internal_server_url).to eq('http://localhost:8200')
        end
      end
    end

    describe '.jwt_issuer' do
      it 'returns the GitLab base URL' do
        expect(secrets_manager.class.jwt_issuer).to eq(Gitlab.config.gitlab.base_url)
      end
    end
  end
end
