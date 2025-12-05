# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Upstreams::Remote::CheckService, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let(:path) { 'com/test/package/1.2.3/package-1.2.3.pom' }
    let(:params) { { path: } }
    let(:upstreams) { registry.upstreams }
    let(:service) do
      described_class.new(upstreams:, params:)
    end

    subject(:execute) { service.execute }

    context 'for maven virtual registries' do
      include_context 'for check upstream service for maven packages'

      let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }
      let_it_be(:upstream1) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
      let_it_be(:upstream2) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
      let_it_be(:upstream3) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

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

        it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
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
    end

    context 'for container virtual registries' do
      include_context 'for check upstream service for container images'

      let_it_be(:registry) { create(:virtual_registries_container_registry) }

      let_it_be(:upstream1) { create(:virtual_registries_container_upstream, registries: [registry]) }
      let_it_be(:upstream2) { create(:virtual_registries_container_upstream, registries: [registry]) }
      let_it_be(:upstream3) { create(:virtual_registries_container_upstream, registries: [registry]) }

      let(:path) { 'library/alpine/manifests/3.19' }
      let(:scope) { 'repository:library/alpine:pull' }

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

        it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
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
    end

    it_behaves_like 'a check upstream service handling no path set'
    it_behaves_like 'a check upstream service handling empty upstreams'
  end
end
