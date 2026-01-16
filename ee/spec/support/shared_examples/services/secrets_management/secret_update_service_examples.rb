# frozen_string_literal: true

RSpec.shared_examples 'a service for updating a secret' do |resource_type|
  # Note: The including spec must define:
  # - service (the service instance)
  # - secrets_manager (the secrets manager instance)
  # - provision_secrets_manager (method to provision the secrets manager)
  # - create_initial_secret (method to create the initial secret for testing)
  # - name (secret name)
  # - metadata_cas (current metadata version)
  # - result (the service execution result)
  # - user (the user performing the operation)

  describe '#execute' do
    context "when the #{resource_type} secrets manager is active" do
      before do
        provision_secrets_manager(secrets_manager, user)
        create_initial_secret
      end

      it_behaves_like "an operation requiring an exclusive #{resource_type} secret operation lease"

      it 'updates the secret successfully', :freeze_time do
        frozen_time = Time.current.utc.iso8601

        expect(result).to be_success
        secret = result.payload[:secret]
        expect(secret).to be_present
        expect(secret.name).to eq(name)

        # Verify update timestamps are set
        expect_kv_secret_to_have_custom_metadata(
          full_namespace_path,
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          "update_started_at" => frozen_time,
          "update_completed_at" => frozen_time
        )
      end

      context 'when metadata_cas does not match' do
        let(:metadata_cas) { 999 }

        it 'fails with CAS error' do
          expect(result).to be_error
          expect(result.message).to include('This secret has been modified recently')
        end
      end

      context 'when metadata_cas is not given' do
        let(:metadata_cas) { nil }

        it 'updates the secret without checking CAS', :freeze_time do
          frozen_time = Time.current.utc.iso8601

          expect(result).to be_success
          secret = result.payload[:secret]
          expect(secret.metadata_version).to be_nil

          # Verify update timestamps are still set
          expect_kv_secret_to_have_custom_metadata(
            full_namespace_path,
            secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "update_started_at" => frozen_time,
            "update_completed_at" => frozen_time
          )
        end
      end

      context 'when the secret does not exist' do
        let(:name) { 'NONEXISTENT_SECRET' }

        it 'fails with not found error' do
          expect(result).to be_error
          expect(result.message).to include("#{resource_type.capitalize} secret does not exist")
          expect(result.reason).to eq(:not_found)
        end
      end
    end

    context "when the #{resource_type} secrets manager is not active" do
      it 'fails with inactive error' do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
      end
    end
  end
end
