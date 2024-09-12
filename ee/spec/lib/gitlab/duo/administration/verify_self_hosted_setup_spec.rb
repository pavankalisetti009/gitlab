# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Administration::VerifySelfHostedSetup, :gitlab_duo, :silence_stdout, feature_category: :"self-hosted_models" do
  include RakeHelpers

  let_it_be(:user) { create(:user, :admin, id: 1) }

  let(:task) { described_class.new }
  let(:rake_task) { instance_double(Rake::Task, invoke: true) }
  let(:ai_gateway_url) { 'http://ai_gateway_url' }
  let(:use_self_signed_token) { "1" }
  let(:license_provides_code_suggestions) { true }
  let(:can_user_access_code_suggestions) { true }
  let(:status_code) { 200 }
  let(:http_response) { instance_double(HTTParty::Response, body: '{}', code: status_code) }

  subject(:verify_setup) { task.execute }

  before do
    allow(Rake::Task).to receive(:[]).with(any_args).and_return(rake_task)

    create_current_license_without_expiration(plan: License::ULTIMATE_PLAN)

    stub_env('AI_GATEWAY_URL', ai_gateway_url)
    stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', use_self_signed_token)
    stub_licensed_features(code_suggestions: license_provides_code_suggestions)
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, :access_code_suggestions)
                                        .and_return(can_user_access_code_suggestions)

    allow(Gitlab::HTTP).to receive(:get).with("#{ai_gateway_url}/monitoring/healthz",
      headers: { "accept" => "application/json" }, allow_local_requests: true)
                                        .and_return(http_response)
  end

  context 'when everything is set properly' do
    it 'rake task succeeds' do
      expect { verify_setup }.not_to raise_error
    end
  end

  context 'when AI_GATEWAY_URL is not set' do
    let(:ai_gateway_url) { nil }

    it 'raises error' do
      expect { verify_setup }.to raise_error(RuntimeError)
    end
  end

  context 'when user does not have :code_suggestions permission' do
    let(:can_user_access_code_suggestions) { false }

    context 'and license provides code suggestions' do
      it 'raises error' do
        expect { verify_setup }.to raise_error(
          RuntimeError,
          /License is correct, but user does not have access to code suggestions/
        )
      end
    end

    context 'and license does not provide code suggestions' do
      let(:license_provides_code_suggestions) { false }

      it 'raises error' do
        expect { verify_setup }.to raise_error(
          RuntimeError,
          /License does not provide access to code suggestions, verify your license/
        )
      end
    end
  end

  it 'enables the feature flag' do
    Feature.disable(:ai_custom_model)

    verify_setup

    expect(Feature.enabled?(:ai_custom_model)).to be(true) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
  end

  context 'when connection to ai_gateway fails' do
    before do
      allow(Gitlab::HTTP).to receive(:get).with("#{ai_gateway_url}/monitoring/healthz",
        headers: { "accept" => "application/json" }, allow_local_requests: true)
                                          .and_raise(Errno::ECONNREFUSED)
    end

    it 'raises error' do
      expect { verify_setup }.to raise_error(RuntimeError)
    end
  end

  context 'when response from ai_gateway is not 200' do
    let(:status_code) { 500 }

    it 'raises error' do
      expect { verify_setup }.to raise_error(RuntimeError)
    end
  end
end
