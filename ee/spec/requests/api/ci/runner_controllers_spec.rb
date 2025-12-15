# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::RunnerControllers, feature_category: :continuous_integration do
  let_it_be(:path) { '/runner_controllers' }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:non_admin_user) { create(:user) }
  let_it_be(:controller) { create(:ci_runner_controller) }

  before do
    stub_licensed_features(ci_runner_controllers: true)
  end

  shared_examples 'returns status 404 (not found)' do
    specify do
      call_endpoint

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET /runner_controllers' do
    context 'when user is admin' do
      it 'returns a list of runner controllers' do
        create_list(:ci_runner_controller, 2)

        get api(path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.size).to eq(3)
      end
    end

    context 'when user is not admin' do
      let_it_be(:user) { create(:user) }

      it 'returns status 403 (forbidden)' do
        get api(path, non_admin_user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      subject(:call_endpoint) { get api(path, admin, admin_mode: true) }

      it_behaves_like 'returns status 404 (not found)'
    end
  end

  describe 'GET /runner_controllers/:id' do
    context 'when user is admin' do
      it 'returns a single runner controller' do
        get api("#{path}/#{controller.id}", admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(controller.id)
      end

      context 'when runner controller does not exist' do
        it 'returns status 404 (not found)' do
          get api("#{path}/#{non_existing_record_id}", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not admin' do
      let_it_be(:user) { create(:user) }

      it 'returns status 403 (forbidden)' do
        get api("#{path}/#{controller.id}", non_admin_user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      subject(:call_endpoint) { get api("#{path}/#{controller.id}", admin, admin_mode: true) }

      it_behaves_like 'returns status 404 (not found)'
    end
  end

  describe 'POST /runner_controllers' do
    context 'when user is admin' do
      it 'creates a new runner controller' do
        params = { description: 'New Controller' }

        post api(path, admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['description']).to eq('New Controller')
      end

      context 'when parameters are invalid' do
        it 'returns status 400 (bad request)' do
          params = { description: FFaker::Lorem.characters(1025) }

          post api(path, admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when user is not admin' do
      it 'returns status 403 (forbidden)' do
        params = { description: 'New Controller' }

        post api(path, non_admin_user), params: params

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      subject(:call_endpoint) { post api(path, admin, admin_mode: true) }

      it_behaves_like 'returns status 404 (not found)'
    end
  end

  describe 'DELETE /runner_controllers/:id' do
    context 'when user is admin' do
      it 'deletes a runner controller' do
        delete api("#{path}/#{controller.id}", admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:no_content)
        expect(::Ci::RunnerController.find_by_id(controller.id)).to be_nil
      end

      context 'when deletion fails' do
        it 'returns status 400 (bad request)' do
          allow_next_found_instance_of(::Ci::RunnerController) do |instance|
            allow(instance).to receive(:destroy).and_return(false)
          end

          delete api("#{path}/#{controller.id}", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when runner controller does not exist' do
        it 'returns status 404 (not found)' do
          delete api("#{path}/#{non_existing_record_id}", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not admin' do
      it 'returns status 403 (forbidden)' do
        delete api("#{path}/#{controller.id}", non_admin_user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      subject(:call_endpoint) { delete api("#{path}/#{controller.id}", admin, admin_mode: true) }

      it_behaves_like 'returns status 404 (not found)'
    end
  end
end
