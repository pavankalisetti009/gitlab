# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::CheckUpstreamsService, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }
  let_it_be(:upstream1) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
  let_it_be(:upstream2) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
  let_it_be(:upstream3) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

  let(:path) { 'com/test/package/1.2.3/package-1.2.3.pom' }
  let(:params) { { path: } }
  let(:service) { described_class.new(registry:, params:) }

  describe '#execute' do
    subject(:execute) { service.execute }

    shared_examples 'returning a service success response with upstream' do
      it { is_expected.to be_success.and have_attributes(payload: { upstream: expected_upstream }) }
    end

    # statuses is an array giving the status for each upstream
    where(:statuses, :expected_upstream) do
      [200, 200, 200] | ref(:upstream1)
      [404, 200, 200] | ref(:upstream2)
      [404, 404, 200] | ref(:upstream3)
    end

    with_them do
      before do
        stub_upstream_request(upstream1, status: statuses[0])
        stub_upstream_request(upstream2, status: statuses[1])
        stub_upstream_request(upstream3, status: statuses[2])
      end

      it_behaves_like 'returning a service success response with upstream'
    end

    context 'when file not found in any upstream' do
      before do
        stub_upstream_request(upstream1, status: 404)
        stub_upstream_request(upstream2, status: 404)
        stub_upstream_request(upstream3, status: 404)
      end

      it { is_expected.to eq(described_class::BASE_ERRORS[:file_not_found_on_upstreams]) }
    end

    context 'when an upstream fails' do
      before do
        stub_upstream_request(upstream1, status: 404)
        stub_upstream_request(upstream2, raise_error: true)
        stub_upstream_request(upstream3, status: 200)
      end

      it 'raises an error' do
        expect { execute }.to raise_error(Gitlab::HTTP::BlockedUrlError)
      end
    end

    context 'when an upstream after the one with the file fails' do
      let(:expected_upstream) { upstream2 }

      before do
        stub_upstream_request(upstream1, status: 404)
        stub_upstream_request(upstream2, status: 200)
        stub_upstream_request(upstream3, raise_error: true)
      end

      it_behaves_like 'returning a service success response with upstream'
    end

    context 'when no path present in the parameters' do
      let(:path) { nil }

      it { is_expected.to eq(described_class::BASE_ERRORS[:path_not_present]) }
    end

    def stub_upstream_request(upstream, status: 200, raise_error: false)
      request = stub_request(:head, upstream.url_for(path)).with(headers: upstream.headers)

      if raise_error
        request.to_raise(Gitlab::HTTP::BlockedUrlError)
      else
        request.to_return(status: status, body: 'test')
      end
    end
  end

  context 'for container virtual registries' do
    let_it_be(:registry) { create(:virtual_registries_container_registry) }
    let_it_be(:upstream1) { create(:virtual_registries_container_upstream, registries: [registry]) }
    let_it_be(:upstream2) { create(:virtual_registries_container_upstream, registries: [registry]) }
    let_it_be(:upstream3) { create(:virtual_registries_container_upstream, registries: [registry]) }

    let(:path) { 'library/alpine/manifests/3.19' }
    let(:scope) { 'repository:library/alpine:pull' }
    let(:params) { { path: } }
    let(:service) { described_class.new(registry:, params:) }

    describe '#execute' do
      subject(:execute) { service.execute }

      shared_examples 'returning a service success response with upstream' do
        it { is_expected.to be_success.and have_attributes(payload: { upstream: expected_upstream }) }
      end

      # statuses is an array giving the status for each upstream
      where(:statuses, :expected_upstream) do
        [200, 200, 200] | ref(:upstream1)
        [404, 200, 200] | ref(:upstream2)
        [404, 404, 200] | ref(:upstream3)
      end

      with_them do
        before do
          stub_upstream_request(upstream1, status: statuses[0], scope: scope)
          stub_upstream_request(upstream2, status: statuses[1], scope: scope)
          stub_upstream_request(upstream3, status: statuses[2], scope: scope)
        end

        it_behaves_like 'returning a service success response with upstream'
      end

      context 'when file not found in any upstream' do
        before do
          stub_upstream_request(upstream1, status: 404, scope: scope)
          stub_upstream_request(upstream2, status: 404, scope: scope)
          stub_upstream_request(upstream3, status: 404, scope: scope)
        end

        it { is_expected.to eq(described_class::BASE_ERRORS[:file_not_found_on_upstreams]) }
      end

      context 'when an upstream fails' do
        before do
          stub_upstream_request(upstream1, status: 404, scope: scope)
          stub_upstream_request(upstream2, raise_error: true, scope: scope)
          stub_upstream_request(upstream3, status: 200, scope: scope)
        end

        it 'raises an error' do
          expect { execute }.to raise_error(Gitlab::HTTP::BlockedUrlError)
        end
      end

      context 'when an upstream after the one with the file fails' do
        let(:expected_upstream) { upstream2 }

        before do
          stub_upstream_request(upstream1, status: 404, scope: scope)
          stub_upstream_request(upstream2, status: 200, scope: scope)
          stub_upstream_request(upstream3, raise_error: true, scope: scope)
        end

        it_behaves_like 'returning a service success response with upstream'
      end

      context 'when no path present in the parameters' do
        let(:path) { nil }

        it { is_expected.to eq(described_class::BASE_ERRORS[:path_not_present]) }
      end

      def stub_upstream_request(upstream, status: 200, raise_error: false, scope: 'repository:test:pull')
        url = upstream.url_for(path)

        # Step 1: Auth discovery - HEAD request returns 401 with WWW-Authenticate header
        stub_request(:head, url)
        .to_return(
          status: 401,
          headers: {
            'www-authenticate' => 'Bearer realm="https://auth.example.com/token",service="registry.example.com",scope="repository:test:pull"'
          }
        )

        # Step 2: Token exchange - GET request to auth service returns bearer token
        stub_request(:get, "https://auth.example.com/token")
          .with(query: {
            "service" => "registry.example.com",
            "scope" => scope
          })
          .to_return(
            status: 200,
            body: '{"token": "fake_bearer_token_123"}'
          )

        # Step 3: Authenticated request - HEAD request with bearer token
        expected_headers = upstream.headers(path).merge(VirtualRegistries::Container::Upstream::REGISTRY_ACCEPT_HEADERS)
        request = stub_request(:head, url).with(headers: expected_headers)

        if raise_error
          request.to_raise(Gitlab::HTTP::BlockedUrlError)
        else
          request.to_return(status: status, body: 'test')
        end
      end
    end
  end
end
