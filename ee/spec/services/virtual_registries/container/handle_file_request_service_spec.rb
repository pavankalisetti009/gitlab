# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::HandleFileRequestService, :aggregate_failures, :clean_gitlab_redis_shared_state, feature_category: :virtual_registry do
  let_it_be(:registry) { create(:virtual_registries_container_registry, :with_upstreams) }
  let_it_be(:project) { create(:project, namespace: registry.group) }
  let_it_be(:user) { create(:user, owner_of: project) }
  let_it_be(:upstream) { registry.upstreams.first }

  let(:etag_returned_by_upstream) { nil }
  let(:service) { described_class.new(registry: registry, current_user: user, params: { path: path }) }

  describe '#execute' do
    subject(:execute) { service.execute }

    shared_examples 'returning a service response success response' do |action:|
      before do
        stub_external_registry_request(etag: etag_returned_by_upstream)
      end

      it 'returns a success service response' do
        expect(service).to receive(:can?).and_call_original

        if action == :download_file
          expect_next_found_instance_of(::VirtualRegistries::Container::Cache::Entry) do |expected_cache_entry|
            expect(expected_cache_entry).to receive(:bump_downloads_count)
          end
        end

        is_expected.to be_success.and have_attributes(payload: a_hash_including(action:))

        case action
        when :workhorse_upload_url
          expect(execute[:action_params]).to eq(
            url: upstream_resource_url,
            upstream: upstream
          )
        when :download_file
          expect(execute[:action_params]).to include(
            file: an_instance_of(VirtualRegistries::Cache::EntryUploader),
            content_type: an_instance_of(String),
            file_sha1: an_instance_of(String)
          )
        end
      end
    end

    context 'with a User' do
      shared_examples 'container request tests' do
        let(:processing_cache_entry) do
          create(
            :virtual_registries_container_cache_entry,
            :upstream_checked,
            :processing,
            relative_path: expected_relative_path,
            upstream: upstream
          )
        end

        context 'with no cache entry' do
          it_behaves_like 'returning a service response success response', action: :workhorse_upload_url

          context 'with upstream returning an error' do
            before do
              stub_external_registry_request(status: 404)
            end

            it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
          end

          context 'with upstream head raising an error' do
            before do
              stub_external_registry_request(raise_error: true)
            end

            it { is_expected.to eq(described_class::ERRORS[:upstream_not_available]) }
          end
        end

        context 'with a cache entry' do
          let!(:cache_entry) do
            create(:virtual_registries_container_cache_entry,
              :upstream_checked,
              upstream: upstream,
              relative_path: expected_relative_path
            )
          end

          it_behaves_like 'returning a service response success response', action: :download_file

          context 'and is too old' do
            before do
              cache_entry.update!(upstream_checked_at: 1.year.ago)
            end

            context 'with the same etag as upstream' do
              let(:etag_returned_by_upstream) { cache_entry.upstream_etag }

              it_behaves_like 'returning a service response success response', action: :download_file

              it 'bumps the statistics', :freeze_time do
                stub_external_registry_request(etag: etag_returned_by_upstream)

                expect { execute }.to change { cache_entry.reload.upstream_checked_at }.to(Time.zone.now)
              end
            end

            context 'with a different etag as upstream' do
              let(:etag_returned_by_upstream) { "#{cache_entry.upstream_etag}_test" }

              it_behaves_like 'returning a service response success response', action: :workhorse_upload_url
            end

            context 'with a stored blank etag' do
              before do
                cache_entry.update!(upstream_etag: nil)
              end

              it_behaves_like 'returning a service response success response', action: :workhorse_upload_url
            end
          end

          context 'with upstream head raising an error' do
            before do
              stub_external_registry_request(raise_error: true)
            end

            it_behaves_like 'returning a service response success response', action: :download_file
          end

          context 'with a cached permissions evaluation' do
            before do
              stub_external_registry_request
              Rails.cache.fetch(service.send(:permissions_cache_key)) do
                can?(user, :read_virtual_registry, registry)
              end
            end

            it 'does not call the permissions evaluation again', :aggregate_failures do
              expect(service).not_to receive(:can)
              expect(execute).to be_success
            end
          end
        end
      end

      context 'when requesting a manifest' do
        let(:path) { 'my/image/manifests/latest' }
        let(:expected_image_name) { 'my/image' }
        let(:expected_relative_path) { 'my/image/manifests/latest' }
        let(:upstream_resource_url) { upstream.url_for(path) }

        it_behaves_like 'container request tests'

        context 'when requesting by digest' do
          let(:path) { 'my/image/manifests/sha256:abc123' }
          let(:expected_relative_path) { 'my/image/manifests/sha256:abc123' }
          let(:upstream_resource_url) { upstream.url_for(path) }

          it_behaves_like 'container request tests'
        end

        context 'with nested image name' do
          let(:path) { 'library/nginx/app/manifests/v1.0' }
          let(:expected_image_name) { 'library/nginx/app' }
          let(:expected_relative_path) { 'library/nginx/app/manifests/v1.0' }
          let(:upstream_resource_url) { upstream.url_for(path) }

          it_behaves_like 'container request tests'
        end
      end

      context 'when requesting a blob' do
        let(:path) { 'my/image/blobs/sha256:def456' }
        let(:expected_image_name) { 'my/image' }
        let(:expected_relative_path) { 'my/image/blobs/sha256:def456' }
        let(:upstream_resource_url) { upstream.url_for(path) }

        it_behaves_like 'container request tests'

        context 'with nested image name' do
          let(:path) { 'library/nginx/app/blobs/sha256:ghi789' }
          let(:expected_image_name) { 'library/nginx/app' }
          let(:expected_relative_path) { 'library/nginx/app/blobs/sha256:ghi789' }
          let(:upstream_resource_url) { upstream.url_for(path) }

          it_behaves_like 'container request tests'
        end
      end
    end

    context 'with a DeployToken' do
      let_it_be(:user) { create(:deploy_token, :group, groups: [registry.group], read_virtual_registry: true) }
      let(:path) { 'my/image/manifests/latest' }
      let(:expected_image_name) { 'my/image' }
      let(:expected_relative_path) { '/v2/my/image/manifests/latest' }
      let(:upstream_resource_url) { upstream.url_for(path) }

      it_behaves_like 'returning a service response success response', action: :workhorse_upload_url
    end

    context 'with no path' do
      let(:path) { nil }

      it { is_expected.to eq(described_class::ERRORS[:path_not_present]) }
    end

    context 'with no user' do
      let(:user) { nil }
      let(:path) { 'my/image/manifests/latest' }

      it { is_expected.to eq(described_class::ERRORS[:unauthorized]) }
    end

    context 'with registry with no upstreams' do
      let(:path) { 'my/image/manifests/latest' }

      before do
        registry.upstreams = []
      end

      it { is_expected.to eq(described_class::ERRORS[:no_upstreams]) }
    end

    def stub_external_registry_request(status: 200, raise_error: false, etag: nil)
      if raise_error
        stub_request(:head, upstream_resource_url).to_raise(Gitlab::HTTP::BlockedUrlError)
        return
      end

      stub_request(:head, upstream_resource_url).to_return(
        status: 401,
        body: '',
        headers: {
          'www-authenticate' => 'Bearer realm="https://auth.example.com/token",service="registry.example.com",scope="repository:library/nginx:pull"'
        }
      ).times(1)

      # Second, stub the token exchange request
      stub_request(:get, %r{auth\.example\.com/token})
        .to_return(
          status: 200,
          body: { token: 'fake-bearer-token' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Finally, stub the actual HEAD request with bearer token
      stub_request(:head, upstream_resource_url)
        .with(
          headers: { 'Authorization' => 'Bearer fake-bearer-token' }
          .merge(VirtualRegistries::Container::Upstream::REGISTRY_ACCEPT_HEADERS)
        ).to_return(status: status, body: '', headers: { 'etag' => etag }.compact)
    end
  end
end
