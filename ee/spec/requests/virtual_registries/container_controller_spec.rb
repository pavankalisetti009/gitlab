# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Virtual Registries Container API', feature_category: :virtual_registry do
  include DependencyProxyHelpers

  let_it_be_with_reload(:group) { create(:group, :private) }
  let_it_be_with_reload(:user) { create(:user, guest_of: group) }
  let_it_be_with_reload(:virtual_registry_setting) { create(:virtual_registries_setting, group: group) }
  let_it_be_with_reload(:registry) { create(:virtual_registries_container_registry, :with_upstreams, group: group) }

  let(:jwt) { build_jwt(user) }
  let(:headers) { jwt_token_authorization_headers(jwt) }

  before do
    stub_licensed_features(container_virtual_registry: true)
    stub_config(dependency_proxy: { enabled: true })
    stub_feature_flags(container_virtual_registries: true)
  end

  shared_examples 'returns unauthorized without a token' do
    it 'returns unauthorized status' do
      get path

      expect(response).to have_gitlab_http_status(:unauthorized)
      expect(response.headers['WWW-Authenticate']).to eq(::DependencyProxy::Registry.authenticate_header)
    end
  end

  shared_examples 'returns not implemented' do
    it_behaves_like 'returning response status with message', status: :not_implemented, message: 'Not implemented' do
      subject { get path, headers: headers }
    end
  end

  shared_examples 'validates feature flags and licensing' do
    context 'when container_virtual_registries feature flag is disabled' do
      before do
        stub_feature_flags(container_virtual_registries: false)
      end

      it 'returns not found' do
        get path, headers: headers

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when container virtual registry is not licensed' do
      before do
        stub_licensed_features(container_virtual_registry: false)
      end

      it 'returns not found' do
        get path, headers: headers

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when dependency proxy is disabled' do
      before do
        stub_config(dependency_proxy: { enabled: false })
      end

      it 'returns not found' do
        get path, headers: headers

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'validates permissions' do
    shared_examples 'returns forbidden' do
      specify do
        get path, headers: headers

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user does not have read_virtual_registry permission' do
      let_it_be(:unauthorized_user) { create(:user) }
      let(:headers) { jwt_token_authorization_headers(build_jwt(unauthorized_user)) }

      it_behaves_like 'returns forbidden'
    end

    context 'when personal access token does not have read_virtual_registry permission' do
      let_it_be(:unauthorized_user) { create(:personal_access_token) }
      let(:headers) { jwt_token_authorization_headers(build_jwt(unauthorized_user)) }

      it_behaves_like 'returns forbidden'
    end

    context 'when deploy token does not have read_virtual_registry permission' do
      let_it_be(:unauthorized_user) { create(:deploy_token) }
      let(:headers) { jwt_token_authorization_headers(build_jwt(unauthorized_user)) }

      it_behaves_like 'returns forbidden'
    end
  end

  shared_examples 'a valid user' do
    it_behaves_like 'returns not implemented'
  end

  shared_examples 'a valid personal access token' do
    let(:pat) { create(:personal_access_token, user: user, scopes: [:read_virtual_registry]) }
    let(:jwt) { build_jwt(pat) }

    it_behaves_like 'returns not implemented'
  end

  shared_examples 'a valid deploy token' do
    let(:user) { create(:deploy_token, :group, read_virtual_registry: true, groups: [group]) }

    it_behaves_like 'returns not implemented'
  end

  # GET /v2/virtual_registries/container/:id/*image/manifests/*tag_or_digest
  describe 'GET manifest' do
    let(:image) { 'alpine' }
    let(:tag) { 'latest' }
    let(:path) { "/v2/virtual_registries/container/#{registry.id}/#{image}/manifests/#{tag}" }

    it { expect(get(path, headers: headers)).to have_request_urgency(:low) }

    it_behaves_like 'returns unauthorized without a token'
    it_behaves_like 'returns not implemented'
    it_behaves_like 'validates feature flags and licensing'
    it_behaves_like 'validates permissions'

    context 'with invalid registry id' do
      let(:path) { "/v2/virtual_registries/container/#{non_existing_record_id}/#{image}/manifests/#{tag}" }

      it 'returns not found' do
        get path, headers: headers

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with tag' do
      it_behaves_like 'a valid user'
      it_behaves_like 'a valid personal access token'
      it_behaves_like 'a valid deploy token'
    end

    context 'with digest' do
      let(:digest) { "sha256:#{'a' * 64}" }
      let(:path) { "/v2/virtual_registries/container/#{registry.id}/#{image}/manifests/#{digest}" }

      it_behaves_like 'a valid user'
      it_behaves_like 'a valid personal access token'
      it_behaves_like 'a valid deploy token'
    end
  end

  # GET /v2/virtual_registries/container/:id/*image/blobs/:sha
  describe 'GET blob' do
    let(:image) { 'alpine' }
    let(:sha) { 'sha256:abc123def456' }
    let(:path) { "/v2/virtual_registries/container/#{registry.id}/#{image}/blobs/#{sha}" }

    it { expect(get(path, headers: headers)).to have_request_urgency(:low) }

    it_behaves_like 'returns unauthorized without a token'
    it_behaves_like 'returns not implemented'
    it_behaves_like 'validates feature flags and licensing'
    it_behaves_like 'validates permissions'

    context 'with full sha256 digest' do
      let(:sha) { "sha256:#{'a' * 64}" }

      it_behaves_like 'a valid user'
      it_behaves_like 'a valid personal access token'
      it_behaves_like 'a valid deploy token'
    end

    context 'with invalid registry id' do
      let(:path) { "/v2/virtual_registries/container/#{non_existing_record_id}/#{image}/blobs/#{sha}" }

      it 'returns not found' do
        get path, headers: headers

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
