# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:secrets_management:openbao', :silence_stdout, feature_category: :secrets_management do
  before do
    Rake.application.rake_require 'tasks/gitlab/secrets_management/openbao'
  end

  describe 'recovery_key_generate' do
    subject(:task) { run_rake_task('gitlab:secrets_management:openbao:recovery_key_retrieve') }

    let(:encoded_jwt) { "encoded_jwt.a.key" }
    let(:returned_recovery_key) { "ffffffffff38b1f97d18a63fb044015a9c776aa7f6c0e071c22bd25c062e586e" }
    let(:active_recovery_key) { SecretsManagement::RecoveryKey.active.take }
    let(:returned_keys) { [returned_recovery_key] }
    let(:recovery_response) do
      {
        "request_id" => "e1dfe66c-e97b-9ff3-acaf-3a6b24c64250",
        "lease_id" => "",
        "renewable" => false,
        "lease_duration" => 0,
        "data" => {
          "backup" => false,
          "complete" => true,
          "keys" => returned_keys,
          "keys_base64" => ["Suei4Rc4sfl9GKY/sEQBWpx3aqf2wOBxwivSXAYuWG4="],
          "n" => 1,
          "pgp_fingerprints" => nil,
          "t" => 1,
          "verification_nonce" => "",
          "verification_required" => false
        },
        "wrap_info" => nil,
        "warnings" => nil,
        "auth" => nil
      }
    end

    before do
      allow_next_instance_of(SecretsManagement::SecretsManagerJwt) do |smj|
        allow(smj).to receive(:encoded).and_return(encoded_jwt)
      end

      allow_next_instance_of(SecretsManagement::SecretsManagerClient) do |smc|
        allow(smc).to receive(:init_rotate_recovery).and_return(recovery_response)
      end
    end

    it 'saves the returned key to database' do
      expect { task }.to change { SecretsManagement::RecoveryKey.count }

      expect(active_recovery_key.key).to eq(returned_recovery_key)
      expect(active_recovery_key.active).to be true
    end

    context 'if there already exists a RecoveryKey in the database' do
      let(:current_recovery_key) { "a" * 64 }
      let!(:old_recovery_key) { create(:sm_recovery_key, key: current_recovery_key, active: true) }

      it 'stores the returned key to db, marks old key as inactive' do
        expect { task }.to change { SecretsManagement::RecoveryKey.count }

        expect(active_recovery_key.key).to eq(returned_recovery_key)
        expect(active_recovery_key.active).to be true

        old_recovery_key.reload

        expect(old_recovery_key.key).to eq(current_recovery_key)
        expect(old_recovery_key.active).to be false
      end
    end

    context 'when the response contains a null key' do
      let(:recovery_response) do
        {
          "request_id" => "e1dfe66c-e97b-9ff3-acaf-3a6b24c64250",
          "lease_id" => "",
          "renewable" => false,
          "lease_duration" => 0,
          "data" => {
            "backup" => false,
            "complete" => true,
            "n" => 1,
            "pgp_fingerprints" => nil,
            "t" => 1,
            "verification_nonce" => "",
            "verification_required" => false
          },
          "wrap_info" => nil,
          "warnings" => nil,
          "auth" => nil
        }
      end

      it "does not persist anything" do
        allow_next_instance_of(SecretsManagement::SecretsManagerClient) do |smc|
          allow(smc).to receive(:init_rotate_recovery).and_return(recovery_response)
          expect(smc).to receive(:cancel_rotate_recovery)
        end

        expect { task }.not_to change { SecretsManagement::RecoveryKey.count }
      end
    end

    context 'when the api raises an exception' do
      let(:exception_class) { SecretsManagement::SecretsManagerClient::ApiError }

      it 'logs the exception by calling track_and_raise_exception' do
        allow_next_instance_of(SecretsManagement::SecretsManagerClient) do |smc|
          expect(smc).to receive(:init_rotate_recovery).and_raise(exception_class)
        end

        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_exception).and_raise(exception_class)

        expect { task }.to raise_exception(exception_class)
      end
    end
  end
end
