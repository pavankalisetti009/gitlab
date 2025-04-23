# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Tokens, feature_category: :cloud_connector do
  describe '.get' do
    let(:token_string) { 'ABCDEF' }
    let(:token_provider) { instance_double(expected_provider_class, token: token_string) }

    before do
      # "Defuse" all counter calls so as not to pollute the tmp folder with metric data.
      allow(::Gitlab::Metrics).to receive(:counter).and_return(Gitlab::Metrics::NullMetric.instance)
    end

    shared_examples 'issues new token' do
      let_it_be(:jwk) { build(:cloud_connector_keys).to_jwk }
      let_it_be(:add_on) { build(:gitlab_subscription_add_on, :duo_enterprise) }
      let_it_be(:group_ids) { [build(:group).id] }

      let(:expected_provider_class) { CloudConnector::Tokens::TokenIssuer }

      let(:oidc_issuer_url) { 'http://gitlab.com' }
      let(:instance_uuid) { '123-ABC' }
      let(:gitlab_realm) { 'realm' }
      let(:extra_claims) { { custom_claim: 'value' } }

      subject(:encoded_token) { described_class.get(root_group_ids: group_ids, extra_claims: extra_claims) }

      before do
        allow(CloudConnector::CachingKeyLoader).to receive(:private_jwk).and_return(jwk)
        allow(CloudConnector).to receive(:gitlab_realm).and_return(gitlab_realm)
        allow(Doorkeeper::OpenidConnect.configuration).to receive(:issuer).and_return(oidc_issuer_url)
        allow(Gitlab::CurrentSettings).to receive(:uuid).and_return(instance_uuid)
        allow(GitlabSubscriptions::AddOn).to receive(:active)
          .with(group_ids)
          .and_return([add_on])
      end

      it 'uses TokenIssuer to obtain a token' do
        expect(expected_provider_class).to receive(:new)
          .with(
            name_or_url: oidc_issuer_url,
            subject: instance_uuid,
            realm: gitlab_realm,
            active_add_ons: ['duo_enterprise'],
            ttl: instance_of(ActiveSupport::Duration),
            jwk: jwk,
            extra_claims: extra_claims
          )
          .and_return(token_provider)

        expect(encoded_token).to eq(token_string)
      end

      context 'when loading add-ons' do
        let_it_be(:add_on) { build(:gitlab_subscription_add_on, :code_suggestions) }

        it 'renames code_suggestions to duo_pro' do
          expect(expected_provider_class).to receive(:new)
            .with(hash_including(active_add_ons: ['duo_pro']))
            .and_return(token_provider)

          expect(encoded_token).to eq(token_string)
        end
      end

      it 'increments the token counter metric' do
        token_counter = instance_double(Prometheus::Client::Counter)
        expect(::Gitlab::Metrics).to receive(:counter)
          .with(:cloud_connector_tokens_issued_total, instance_of(String), worker_id: instance_of(String))
          .and_return(token_counter)
        expect(token_counter).to receive(:increment).with(kid: jwk.kid)

        encoded_token
      end
    end

    context 'when a self-issued token should be used' do
      context 'when on gitlab.com' do
        before do
          stub_saas_features(cloud_connector_self_signed_tokens: true)
        end

        it_behaves_like 'issues new token'
      end

      context 'when self-hosted models are configured' do
        before do
          allow(::Ai::Setting).to receive(:self_hosted?).and_return(true)
        end

        it_behaves_like 'issues new token'
      end

      context 'when CLOUD_CONNECTOR_SELF_SIGN_TOKENS is set' do
        before do
          stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', '1')
        end

        it_behaves_like 'issues new token'
      end
    end

    context 'when a stored token should be used' do
      let(:expected_provider_class) { CloudConnector::Tokens::TokenLoader }

      subject(:encoded_token) { described_class.get }

      before do
        allow(expected_provider_class).to receive(:new).and_return(token_provider)
      end

      it 'uses TokenLoader to obtain a token' do
        expect(encoded_token).to eq(token_string)
      end

      it 'does not increment the token counter metric' do
        expect(::Gitlab::Metrics).not_to receive(:counter)
          .with(:cloud_connector_tokens_issued_total, instance_of(String), instance_of(Hash))

        encoded_token
      end
    end
  end
end
