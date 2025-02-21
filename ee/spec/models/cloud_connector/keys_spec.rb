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
end
