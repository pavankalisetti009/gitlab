# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Virtual Registry routing', "routing", feature_category: :virtual_registry do
  describe 'Virtual Registries for Containers' do
    let(:registry_id) { '1' }
    let(:image) { 'alpine' }
    let(:tag) { 'latest' }
    let(:digest) { "sha256:#{'a' * 64}" }
    let(:sha) { 'sha256:abc123def456' }

    shared_examples 'routes correctly' do |action:, param_name:|
      it "routes to container##{action}" do
        expect(get(path))
          .to route_to(
            controller: 'virtual_registries/container',
            action: action,
            id: registry_id,
            image: expected_image,
            param_name => expected_value
          )
      end
    end

    shared_examples 'does not route' do |action:, param_name:|
      it "does not route to container##{action}" do
        expect(get(path))
          .not_to route_to(
            controller: 'virtual_registries/container',
            action: action,
            id: registry_id,
            image: expected_image,
            param_name => expected_value
          )
      end
    end

    describe 'GET /v2/virtual_registries/container/:id/*image/manifests/*tag_or_digest' do
      where(:image_name, :identifier) do
        [
          ['alpine',          ref(:tag)],
          ['alpine',          ref(:digest)],
          ['library/alpine',  ref(:tag)],
          ['library/alpine',  ref(:digest)],
          ['foo/bar/baz/qux', ref(:tag)],
          ['foo/bar/baz/qux', ref(:digest)]
        ]
      end

      with_them do
        let(:path) { "/v2/virtual_registries/container/#{registry_id}/#{image_name}/manifests/#{identifier}" }
        let(:expected_image) { image_name }
        let(:expected_value) { identifier }

        it_behaves_like 'routes correctly', action: 'manifest', param_name: :tag_or_digest
      end

      context 'with valid tag characters' do
        where(:tag_name) do
          [
            ['v1.2.3'],
            ['feature-branch'],
            ['feature_branch'],
            ['_internal'],
            ['v1.2.3-rc.1_build.123']
          ]
        end

        with_them do
          let(:path) { "/v2/virtual_registries/container/#{registry_id}/#{image}/manifests/#{tag_name}" }
          let(:expected_image) { image }
          let(:expected_value) { tag_name }

          it_behaves_like 'routes correctly', action: 'manifest', param_name: :tag_or_digest
        end
      end

      context 'with invalid tag names' do
        where(:tag_name) do
          [
            ['-invalid'], # has hyphen
            ['a' * 129], # too long
            ["md5:#{'a' * 32}"], # unsupported digest format
            ["sha256:#{'a' * 63}"], # invalid sha256 length
            ["sha256:#{'A' * 64}"], # has uppercase character
            ["sha256:#{'g' * 64}"]  # has hex character
          ]
        end

        with_them do
          let(:path) { "/v2/virtual_registries/container/#{registry_id}/#{image}/manifests/#{tag_name}" }
          let(:expected_image) { image }
          let(:expected_value) { tag_name }

          it_behaves_like 'does not route', action: 'manifest', param_name: :tag_or_digest
        end
      end

      context 'with invalid image name' do
        let(:path) { "/v2/virtual_registries/container/#{registry_id}/invalid*/manifests/#{tag}" }
        let(:expected_image) { 'invalid*' }
        let(:expected_value) { tag }

        it_behaves_like 'does not route', action: 'manifest', param_name: :tag_or_digest
      end
    end

    describe 'GET /v2/virtual_registries/container/:id/*image/blobs/:sha' do
      where(:image_name) do
        [
          ['alpine'],
          ['library/alpine'],
          ['foo/bar/baz/qux']
        ]
      end

      with_them do
        let(:path) { "/v2/virtual_registries/container/#{registry_id}/#{image_name}/blobs/#{sha}" }
        let(:expected_image) { image_name }
        let(:expected_value) { sha }

        it_behaves_like 'routes correctly', action: 'blob', param_name: :sha
      end

      context 'with full sha256 digest' do
        let(:full_digest) { "sha256:#{'a' * 64}" }
        let(:path) { "/v2/virtual_registries/container/#{registry_id}/#{image}/blobs/#{full_digest}" }
        let(:expected_image) { image }
        let(:expected_value) { full_digest }

        it_behaves_like 'routes correctly', action: 'blob', param_name: :sha
      end

      context 'with invalid sha format' do
        where(:invalid_sha) do
          [
            ['invalid'],
            ['sha256:..%2F..']
          ]
        end

        with_them do
          let(:path) { "/v2/virtual_registries/container/#{registry_id}/#{image}/blobs/#{invalid_sha}" }
          let(:expected_image) { image }
          let(:expected_value) { invalid_sha }

          it_behaves_like 'does not route', action: 'blob', param_name: :sha
        end
      end

      context 'with invalid image name' do
        let(:path) { "/v2/virtual_registries/container/#{registry_id}/invalid*/blobs/#{sha}" }
        let(:expected_image) { 'invalid*' }
        let(:expected_value) { sha }

        it_behaves_like 'does not route', action: 'blob', param_name: :sha
      end
    end
  end
end
