# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe ::RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator, feature_category: :workspaces do
  let(:expected_redirect_uri_scheme) { "http" }

  let(:expected_oauth_application_attributes) do
    {
      name: "GitLab Workspaces",
      redirect_uri: "#{expected_redirect_uri_scheme}://host:3000/-/kubernetes-agent/workspaces/oauth/redirect",
      scopes: "openid",
      trusted:
        RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator::TRUSTED,
      confidential:
        RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator::CONFIDENTIAL
    }
  end

  let(:external_url_scheme) { "ws" }
  let(:gitlab_kas_external_url) { "#{external_url_scheme}://host:3000/-/kubernetes-agent" }
  let(:settings) { { gitlab_kas_external_url: gitlab_kas_external_url } }

  let(:context) { { settings: settings } }

  subject(:oauth_application_attributes) do
    described_class.generate(context)[:oauth_application_attributes]
  end

  it "returns the expected oauth application attributes" do
    expect(oauth_application_attributes).to eq(expected_oauth_application_attributes)
  end

  context "when the external URL scheme is grpcs or wss" do
    let(:external_url_scheme) { "wss" }
    let(:expected_redirect_uri_scheme) { "https" }

    it "uses https as the redirect URI scheme" do
      expect(oauth_application_attributes).to eq(expected_oauth_application_attributes)
    end
  end
end
