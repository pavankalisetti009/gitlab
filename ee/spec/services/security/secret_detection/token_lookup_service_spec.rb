# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::TokenLookupService, feature_category: :secret_detection do
  let(:service) { described_class.new }

  describe '#find' do
    context 'with multiple personal access tokens and PAT routable tokens' do
      let(:token_values) do
        Array.new(4) { |i| format('glpat-%020d', i) } +
          Array.new(4) { |i| format('glpat-%027d', i) }
      end

      let(:personal_access_tokens) { create_list(:personal_access_token, token_values.size) }

      before do
        token_values.each_with_index do |value, index|
          personal_access_tokens[index].update_column(:token_digest, Gitlab::CryptoHelper.sha256(value))
        end
      end

      it 'finds the tokens' do
        result = service.find('gitlab_personal_access_token', token_values)
        expect(result.size).to eq(token_values.size)
        token_values.each_with_index do |_, index|
          expect(result[index].token_digest).to eq(personal_access_tokens[index].token_digest)
        end
      end
    end

    context 'when searching for existing and non-existing tokens' do
      let(:existing_token_values) { Array.new(3) { |i| format('glpat-%020d', i) } }
      let(:non_existing_token_values) { Array.new(2) { |i| format('glpat-nonexistent%015d', i) } }
      let(:all_token_values) { existing_token_values + non_existing_token_values }
      let(:existing_tokens) { create_list(:personal_access_token, existing_token_values.size) }

      before do
        existing_token_values.each_with_index do |value, index|
          existing_tokens[index].update_column(:token_digest, Gitlab::CryptoHelper.sha256(value))
        end
      end

      it 'finds only the existing tokens' do
        result = service.find('gitlab_personal_access_token', all_token_values)

        expect(result.size).to eq(existing_token_values.size)
        existing_token_values.each_with_index do |_, index|
          expect(result).to include(existing_tokens[index])
        end

        non_existing_token_values.each do |value|
          digest = Gitlab::CryptoHelper.sha256(value)
          expect(result.map(&:token_digest)).not_to include(digest)
        end
      end
    end

    context 'with unknown token type' do
      let(:token_value) { 'glpat-00000000000000000000' }
      let(:personal_access_token) { create(:personal_access_token) }

      before do
        personal_access_token.update_column(:token_digest, Gitlab::CryptoHelper.sha256(token_value))
      end

      it 'returns nil' do
        result = service.find('unknown_token_type', [token_value])

        expect(result).to be_nil
      end
    end

    context 'when token not found in database' do
      it 'returns an empty collection' do
        result = service.find('gitlab_personal_access_token', ['glpat-nonexistenttoken12345'])

        expect(result).to be_empty
      end
    end
  end
end
