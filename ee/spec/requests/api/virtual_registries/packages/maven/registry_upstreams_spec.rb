# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::VirtualRegistries::Packages::Maven::RegistryUpstreams, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for maven virtual registry api setup'

  describe 'PATCH /api/v4/virtual_registries/packages/maven/registry_upstreams/:id' do
    let(:registry_upstream) { create(:virtual_registries_packages_maven_registry_upstream, registry:) }
    let(:url) { "/virtual_registries/packages/maven/registry_upstreams/#{registry_upstream.id}" }

    subject(:api_request) { patch api(url), headers: headers, params: params }

    context 'with valid params' do
      let(:params) { { position: 5 } }

      it { is_expected.to have_request_urgency(:low) }

      it_behaves_like 'disabled virtual_registry_maven feature flag'
      it_behaves_like 'maven virtual registry disabled dependency proxy'
      it_behaves_like 'maven virtual registry not authenticated user'
      it_behaves_like 'maven virtual registry feature not licensed'

      where(:user_role, :status) do
        :owner      | :ok
        :maintainer | :ok
        :developer  | :forbidden
        :reporter   | :forbidden
        :guest      | :forbidden
      end

      with_them do
        before do
          group.send(:"add_#{user_role}", user)
        end

        it_behaves_like 'returning response status', params[:status]
      end

      context 'for authentication' do
        before_all do
          group.add_maintainer(user)
        end

        where(:token, :sent_as, :status) do
          :personal_access_token | :header     | :ok
          :deploy_token          | :header     | :forbidden
          :job_token             | :header     | :ok
        end

        with_them do
          let(:headers) { token_header(token) }

          it_behaves_like 'returning response status', params[:status]
        end
      end
    end

    context 'with invalid params' do
      [0, -1, 'a', 21].each do |position|
        context "when position is #{position}" do
          let(:params) { { position: position } }

          it 'returns a bad request' do
            api_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response).to match({ 'error' => /position does not have a valid value/ })
          end
        end
      end
    end
  end
end
