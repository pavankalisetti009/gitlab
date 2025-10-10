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

  describe 'before_actions' do
    let_it_be(:model) { create(:project) }
    let_it_be(:model_name) { Gitlab::Geo::ModelMapper.convert_to_name(model.class) }
    let_it_be(:id) { model.id }

    context 'when the data_management licensed feature is available' do
      before do
        stub_licensed_features(data_management: true)
      end

      it '#index renders template' do
        get index_path
        expect(response).to render_template(:index)
      end

      it '#show renders template' do
        get show_path
        expect(response).to render_template(:show)
      end
    end

    context 'when the data_management licensed feature is not available' do
      before do
        stub_licensed_features(data_management: false)
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

  context 'when model is valid' do
    let_it_be(:default_model) { ::Gitlab::Geo::ModelMapper.available_models.first }

    where(model_classes: Gitlab::Geo::ModelMapper.available_models)
    with_them do
      let(:model_name) { Gitlab::Geo::ModelMapper.convert_to_name(model_classes) }
      let(:model) { create(factory_name(model_classes)) } # rubocop:disable Rails/SaveBang -- this is creating a factory, not a record
      let(:id) { model.id }

      describe '#index' do
        it 'assigns @model_class with the correct class' do
          get index_path

          expect(assigns(:model_class)).to eq(model_classes)
          expect(response).to render_template(:index)
        end

        it 'uses the default model when no model_name parameter' do
          get path

          expect(assigns(:model_class)).to eq(default_model)
        end
      end

      describe '#show' do
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

    it 'show renders 404' do
      get show_path

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  context 'when model is invalid' do
    let(:model_name) { 'invalid' }
    let(:id) { 1 }

    it 'index renders 404' do
      get index_path

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'show renders 404' do
      get show_path

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end
end
