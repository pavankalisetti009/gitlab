# frozen_string_literal: true

module Admin
  class DataManagementController < Admin::ApplicationController
    feature_category :geo_replication
    urgency :low

    # TODO: Remove in https://gitlab.com/gitlab-org/gitlab/-/issues/575225
    before_action :ensure_feature_available!

    authorize! :read_admin_data_management, only: [:index, :show]

    def index
      @models = model_params[:model_name].blank? ? default_model.all : all_models
    end

    def show
      return render_404 unless model_class

      @model = model_class.find(model_params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    private

    def ensure_feature_available!
      render_404 unless License.feature_available?(:data_management)
      render_404 unless Feature.enabled?(:geo_primary_verification_view, current_user)
    end

    def all_models
      return render_404 unless model_class

      model_class.all
    end

    def model_class
      @model_class ||= ::Gitlab::Geo::ModelMapper.find_from_name(model_params[:model_name])
    end

    def default_model
      @default_model ||= ::Gitlab::Geo::ModelMapper.available_models.first
    end

    def model_params
      params.permit(:model_name, :id)
    end
  end
end
