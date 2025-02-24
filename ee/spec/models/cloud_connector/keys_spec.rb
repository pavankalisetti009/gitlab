# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Keys, :models, feature_category: :cloud_connector do
  describe 'validations' do
    subject(:key_record) { create(:cloud_connector_keys) }

    it { is_expected.to be_valid }

    context 'when secret_key is nil' do
      before do
        key_record.secret_key = nil
      end

      it { is_expected.to be_valid }
    end

    context 'when secret_key is not a valid RSA key' do
      before do
        key_record.secret_key = ''
      end

      it { is_expected.not_to be_valid }
    end
  end

  shared_examples 'serving valid keys' do
    context 'when there are no records' do
      it { is_expected.to be_empty }
    end

    context 'when there are records but the key is nil' do
      let_it_be(:key_record) { create(:cloud_connector_keys, secret_key: nil) }

      it { is_expected.to be_empty }
    end

    context 'when there are valid records' do
      let_it_be(:key_record) { create_list(:cloud_connector_keys, 2) }

      it { is_expected.to have_attributes(size: 2) }
    end
  end

  describe '.valid' do
    subject(:jwks) { described_class.valid }

    include_examples 'serving valid keys'
  end

  describe '.all_as_pem' do
    subject(:jwks) { described_class.all_as_pem }

    include_examples 'serving valid keys'

    context 'when there are valid records' do
      let_it_be(:key_record) { create_list(:cloud_connector_keys, 2) }

      it { is_expected.to all(match(/^-----BEGIN RSA PRIVATE KEY-----/)) }
    end
  end

  describe '.current' do
    subject(:jwk) { described_class.current }

    context 'when there are no records' do
      it { is_expected.to be_nil }
    end

    context 'when there are records' do
      context 'and the key is nil' do
        let_it_be(:key_record) { create(:cloud_connector_keys, secret_key: nil) }

        it { is_expected.to be_nil }
      end

      context 'and they are valid' do
        let_it_be(:key_record) { create(:cloud_connector_keys) }

        context 'and there is exactly one record' do
          it { is_expected.to eq(key_record) }
        end

        context 'and there are multiple records', :freeze_time do
          it 'returns the oldest record' do
            oldest_record = create(:cloud_connector_keys, created_at: key_record.created_at - 1.day)

            expect(jwk).to eq(oldest_record)
          end
        end
      end
    end
  end

  describe '.current_as_jwk' do
    subject(:jwk) { described_class.current_as_jwk }

    context 'when there are no records' do
      it { is_expected.to be_nil }
    end

    context 'when there are records' do
      let_it_be(:key_record) { create(:cloud_connector_keys) }

      context 'and there is exactly one record' do
        it { is_expected.to be_a(JWT::JWK::RSA) }

        it 'uses RFC 7638 thumbprint key generator to compute kid' do
          expect(::JWT::JWK).to receive(:new)
            .with(kind_of(OpenSSL::PKey::RSA), kid_generator: ::JWT::JWK::Thumbprint)
            .and_call_original

          expect(jwk.kid).to be_an_instance_of(String)
        end
      end

      context 'and there are multiple records', :freeze_time do
        it 'returns the oldest record as JWK' do
          oldest_record = create(:cloud_connector_keys, created_at: key_record.created_at - 1.day)

          expect(jwk.signing_key.to_pem).to eq(oldest_record.secret_key)
        end

        it 'does not send more than one query' do
          queries = ActiveRecord::QueryRecorder.new do
            described_class.current_as_jwk
          end

          expect(queries.count).to eq(1)
        end
      end
    end
  end
end
