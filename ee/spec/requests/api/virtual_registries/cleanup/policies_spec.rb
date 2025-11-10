# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::VirtualRegistries::Cleanup::Policies, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for virtual registry api setup'

  let(:group_id) { group.id }
  let(:url) { "/groups/#{group_id}/-/virtual_registries/cleanup/policy" }

  before do
    stub_licensed_features(packages_virtual_registry: true)
  end

  shared_examples 'container and packages virtual registry features not licensed' do
    before do
      stub_licensed_features(packages_virtual_registry: false)
      stub_licensed_features(container_virtual_registry: false)
    end

    it_behaves_like 'returning response status', :not_found
  end

  shared_examples 'container and packages virtual registry not available' do
    it_behaves_like 'disabled virtual_registry feature flag', :maven, status: :not_found
    it_behaves_like 'virtual registry disabled dependency proxy'
    it_behaves_like 'virtual registry not authenticated user'
    it_behaves_like 'container and packages virtual registry features not licensed'
    it_behaves_like 'virtual registries setting enabled is false'
    it_behaves_like 'with a non owner user'
  end

  shared_examples 'with a non owner user' do
    let(:user) { create(:user) }

    where(:role) do
      %i[maintainer reporter developer guest]
    end

    with_them do
      before do
        group.send(:"add_#{role}", user)
      end

      it_behaves_like 'returning response status', :forbidden
    end
  end

  shared_examples 'with invalid group_id' do
    where(:group_id) do
      [non_existing_record_id, 'foo', '']
    end

    with_them do
      it_behaves_like 'returning response status', :not_found
    end
  end

  describe 'GET /api/v4/groups/:id/-/virtual_registries/cleanup/policy' do
    let_it_be(:policy) { create(:virtual_registries_cleanup_policy, group:) }

    subject(:api_request) { get api(url), headers: }

    it { is_expected.to have_request_urgency(:low) }

    it 'returns a successful response' do
      api_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(Gitlab::Json.parse(response.body)).to eq(
        policy.as_json.except('id', 'notify_on_success', 'notify_on_failure')
      )
    end

    it_behaves_like 'container and packages virtual registry not available'
    it_behaves_like 'an authenticated virtual registry REST API'
    it_behaves_like 'with invalid group_id'

    context 'with subgroup' do
      let(:group) { create(:group, parent: super()) }

      it_behaves_like 'returning response status', :forbidden
    end
  end

  describe 'POST /api/v4/groups/:id/-/virtual_registries/cleanup/policy' do
    let(:params) { {} }

    subject(:api_request) { post api(url), headers:, params: }

    it { is_expected.to have_request_urgency(:low) }

    it 'returns a successful response' do
      expect { api_request }.to change { VirtualRegistries::Cleanup::Policy.count }.by(1)

      expect(response).to have_gitlab_http_status(:created)
      expect(Gitlab::Json.parse(response.body)).to eq(
        VirtualRegistries::Cleanup::Policy.last.as_json.except('id', 'notify_on_success', 'notify_on_failure')
      )
    end

    it_behaves_like 'container and packages virtual registry not available'
    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :created
    it_behaves_like 'with invalid group_id'

    context 'with invalid params' do
      where(:enabled, :keep_n_days_after_download, :cadence, :error_message) do
        ''   | 30  | 7 | 'enabled is empty'
        true | 370 | 7 | 'keep_n_days_after_download does not have a valid value'
        true | 30  | 0 | 'cadence does not have a valid value'
      end

      with_them do
        let(:params) { { enabled:, keep_n_days_after_download:, cadence: } }

        it_behaves_like 'returning response status with error', status: :bad_request,
          error: params[:error_message]
      end
    end

    context 'with existing policy' do
      before do
        create(:virtual_registries_cleanup_policy, group:)
      end

      it_behaves_like 'returning response status with message', status: :bad_request,
        message: { 'group' => ['has already been taken'] }
    end

    context 'with subgroup' do
      let(:group) { create(:group, parent: super()) }

      it_behaves_like 'returning response status', :forbidden
    end
  end

  describe 'PATCH /api/v4/groups/:id/-/virtual_registries/cleanup/policy' do
    let_it_be(:policy) { create(:virtual_registries_cleanup_policy, group:) }
    let(:params) { { enabled: true, keep_n_days_after_download: 60 } }

    subject(:api_request) { patch api(url), headers:, params: }

    it { is_expected.to have_request_urgency(:low) }

    it 'returns a successful response' do
      expect { api_request }.to change { policy.reset.enabled }.to(params[:enabled])
        .and change { policy.keep_n_days_after_download }.to(params[:keep_n_days_after_download])

      expect(response).to have_gitlab_http_status(:ok)
    end

    it_behaves_like 'container and packages virtual registry not available'
    it_behaves_like 'an authenticated virtual registry REST API'
    it_behaves_like 'with invalid group_id'

    context 'with invalid params' do
      where(:enabled, :keep_n_days_after_download, :cadence, :error_message) do
        ''   | 30  | 7 | 'enabled is empty'
        true | 370 | 7 | 'keep_n_days_after_download does not have a valid value'
        true | 30  | 0 | 'cadence does not have a valid value'
      end

      with_them do
        let(:params) { { enabled:, keep_n_days_after_download:, cadence: } }

        it_behaves_like 'returning response status with error', status: :bad_request,
          error: params[:error_message]
      end
    end
  end

  describe 'DELETE /api/v4/groups/:id/-/virtual_registries/cleanup/policy' do
    let_it_be(:policy) { create(:virtual_registries_cleanup_policy, group:) }

    subject(:api_request) { delete api(url), headers: }

    it { is_expected.to have_request_urgency(:low) }

    it 'returns a successful response' do
      expect { api_request }.to change { VirtualRegistries::Cleanup::Policy.count }.by(-1)

      expect(response).to have_gitlab_http_status(:no_content)
      expect { policy.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it_behaves_like 'container and packages virtual registry not available'
    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :no_content
  end
end
