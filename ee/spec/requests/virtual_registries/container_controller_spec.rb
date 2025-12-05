# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::ContainerController, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include DependencyProxyHelpers

  let_it_be_with_reload(:group) { create(:group, :private) }
  let_it_be_with_reload(:user) { create(:user, guest_of: group) }
  let_it_be_with_reload(:virtual_registry_setting) { create(:virtual_registries_setting, group: group) }
  let_it_be_with_reload(:registry) { create(:virtual_registries_container_registry, :with_upstreams, group: group) }

  let(:jwt) { build_jwt(user) }
  let(:headers) { jwt_token_authorization_headers(jwt) }

  let_it_be(:upstream) { create(:virtual_registries_container_upstream, group: group) }
  let_it_be(:cache_entry) do
    create(
      :virtual_registries_container_cache_entry,
      group: group,
      upstream: upstream,
      relative_path: '/alpine/manifests/latest'
    )
  end

  let(:action) { :download_file }
  let(:upstream_etag) { 'sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08' }
  let(:service_response) do
    ServiceResponse.success(
      payload: {
        action: action,
        action_params: {
          file: cache_entry.file,
          content_type: 'application/vnd.docker.distribution.manifest.v2+json',
          upstream_etag: upstream_etag
        }
      }
    )
  end

  let(:service_double) do
    instance_double(::VirtualRegistries::Container::HandleFileRequestService, execute: service_response)
  end

  before do
    stub_licensed_features(container_virtual_registry: true)
    stub_config(dependency_proxy: { enabled: true })
    stub_feature_flags(container_virtual_registries: true)

    allow(::VirtualRegistries::Container::HandleFileRequestService)
      .to receive(:new)
      .and_return(service_double)
  end

  shared_examples 'returns unauthorized without a token' do
    it 'returns unauthorized status' do
      get path

      expect(response).to have_gitlab_http_status(:unauthorized)
      expect(response.headers['WWW-Authenticate']).to eq(::DependencyProxy::Registry.authenticate_header)
    end
  end

  shared_examples 'returns successful response' do
    context 'when the handle request service returns download_file' do
      it 'returns a successful response' do
        get path, headers: headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['Docker-Distribution-Api-Version']).to eq('registry/2.0')
        expect(response.headers['Content-Type']).to eq('application/vnd.docker.distribution.manifest.v2+json')
        expect(response.headers['Docker-Content-Digest']).to eq(upstream_etag) if expect_digest_header
      end
    end

    context 'when the handle request service returns workhorse_upload_url' do
      let(:action) { :workhorse_upload_url }

      it 'returns not implemented' do
        get path, headers: headers

        expect(response).to have_gitlab_http_status(:not_implemented)
      end
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
    it_behaves_like 'returns successful response'
  end

  shared_examples 'a valid personal access token' do
    let(:pat) { create(:personal_access_token, user: user, scopes: [:read_virtual_registry]) }
    let(:jwt) { build_jwt(pat) }

    it_behaves_like 'returns successful response'
  end

  shared_examples 'a valid deploy token' do
    let(:user) { create(:deploy_token, :group, read_virtual_registry: true, groups: [group]) }

    it_behaves_like 'returns successful response'
  end

  shared_examples 'handles service response errors' do
    where(:reason, :expected_status) do
      :unauthorized                      | :forbidden
      :no_upstreams                      | :not_found
      :file_not_found_on_upstreams       | :not_found
      :upstream_not_available            | :service_unavailable
      :default_error                     | :bad_request
    end

    with_them do
      let(:service_response) do
        ServiceResponse.error(message: 'error', reason: reason)
      end

      it "returns a #{params[:expected_status]} response" do
        get path, headers: headers

        expect(response).to have_gitlab_http_status(expected_status)
      end
    end
  end

  shared_examples 'common file request behavior' do
    it { expect(get(path, headers: headers)).to have_request_urgency(:low) }

    it_behaves_like 'returns unauthorized without a token'
    it_behaves_like 'returns successful response'
    it_behaves_like 'validates feature flags and licensing'
    it_behaves_like 'validates permissions'
    it_behaves_like 'handles service response errors'

    context 'with invalid registry id' do
      let(:path) { "/v2/virtual_registries/container/#{non_existing_record_id}/#{image}/#{path_suffix}" }

      it 'returns not found' do
        get path, headers: headers

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  # GET /v2/virtual_registries/container/:id/*path
  describe 'GET show' do
    let(:image) { 'alpine' }

    context 'with manifest requests' do
      let(:expect_digest_header) { true }
      let(:tag) { 'latest' }
      let(:path_suffix) { "manifests/#{tag}" }
      let(:path) { "/v2/virtual_registries/container/#{registry.id}/#{image}/#{path_suffix}" }

      it_behaves_like 'common file request behavior'

      context 'with tag' do
        it_behaves_like 'a valid user'
        it_behaves_like 'a valid personal access token'
        it_behaves_like 'a valid deploy token'
      end

      context 'with digest' do
        let(:digest) { "sha256:#{'a' * 64}" }
        let(:path_suffix) { "manifests/#{digest}" }
        let(:path) { "/v2/virtual_registries/container/#{registry.id}/#{image}/#{path_suffix}" }

        it_behaves_like 'a valid user'
        it_behaves_like 'a valid personal access token'
        it_behaves_like 'a valid deploy token'
      end
    end

    context 'with blob requests' do
      let(:expect_digest_header) { false }
      let(:sha) { 'sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08' }
      let(:path_suffix) { "blobs/#{sha}" }
      let(:path) { "/v2/virtual_registries/container/#{registry.id}/#{image}/#{path_suffix}" }

      it_behaves_like 'common file request behavior'

      context 'with full sha256 digest' do
        let(:sha) { "sha256:#{'a' * 64}" }

        it_behaves_like 'a valid user'
        it_behaves_like 'a valid personal access token'
        it_behaves_like 'a valid deploy token'
      end
    end
  end
end
