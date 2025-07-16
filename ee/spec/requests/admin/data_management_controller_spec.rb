# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::DataManagementController, :enable_admin_mode, feature_category: :geo_replication do
  include AdminModeHelper
  include EE::GeoHelpers

  let_it_be(:admin) { create(:admin) }

  let(:path) { admin_data_management_path }
  let(:show_path) { "#{path}/#{model_name}/#{id}" }
  let(:index_path) { "#{path}/#{model_name}" }

  before do
    sign_in(admin)
  end

  shared_examples 'pushes geo_primary_verification_view feature flag' do
    it 'pushes the feature flag' do
      get example_path

      expect(response.body).to have_pushed_frontend_feature_flags(geoPrimaryVerificationView: true)
    end
  end

  describe 'before_actions' do
    let(:model_name) { 'project' }
    let(:id) { 1 }

    describe '#license_paid?' do
      context 'when license is not paid' do
        before do
          allow(License).to receive(:current).and_return(nil)
        end

        it '#index renders 404' do
          get index_path
          expect(response).to have_gitlab_http_status(:not_found)
        end

        it '#show renders 404' do
          get show_path
          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    describe '#flag_enabled?' do
      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(geo_primary_verification_view: false)
        end

        it '#index renders 404' do
          get index_path
          expect(response).to have_gitlab_http_status(:not_found)
        end

        it '#show renders 404' do
          get show_path
          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  context 'when model is valid' do
    where(model_classes: Gitlab::Geo::Replicator.subclasses.map(&:model))

    with_them do
      let(:model_name) { Gitlab::Geo::ModelMapper.convert_to_name(model_classes) }
      let(:model) { create(factory_name(model_classes)) } # rubocop:disable Rails/SaveBang -- this is creating a factory, not a record
      let(:id) { model.id }

      describe '#index' do
        it_behaves_like 'pushes geo_primary_verification_view feature flag' do
          let(:example_path) { index_path }
        end

        it 'assigns @models with all records from model_class' do
          get index_path

          expect(assigns(:models)).to eq(model_classes.all)
          expect(response).to render_template(:index)
        end

        it 'uses the default model when no model_name parameter' do
          default_model = ::Gitlab::Geo::ModelMapper.available_models.first

          get path

          expect(assigns(:models)).to eq(default_model.all)
        end
      end

      describe '#show' do
        it_behaves_like 'pushes geo_primary_verification_view feature flag' do
          let(:example_path) { show_path }
        end

        it 'assigns @model with the record found from ID' do
          get show_path

          expect(assigns(:model)).to eq(model)
          expect(response).to render_template(:show)
        end
      end
    end
  end

  context 'when model is not found' do
    let(:model_name) { 'project' }
    let(:id) { 999 }

    it 'renders 404' do
      get show_path

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  context 'when model is invalid' do
    let(:model_name) { 'invalid' }
    let(:id) { 1 }

    it 'renders 404' do
      get index_path

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'renders 404' do
      get show_path

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end
end
