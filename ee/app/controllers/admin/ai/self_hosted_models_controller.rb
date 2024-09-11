# frozen_string_literal: true

module Admin
  module Ai
    class SelfHostedModelsController < Admin::ApplicationController
      include ::GitlabSubscriptions::CodeSuggestionsHelper

      feature_category :"self-hosted_models"
      urgency :low

      before_action :ensure_registration!
      before_action :ensure_feature_enabled!

      def index
        @self_hosted_models = ::Ai::SelfHostedModel.all
      end

      def new
        @self_hosted_model = ::Ai::SelfHostedModel.new
      end

      def create
        service_result = ::Ai::SelfHostedModels::CreateService.new(current_user, self_hosted_models_params).execute

        if service_result.success?
          @self_hosted_model = service_result.payload
          redirect_to admin_ai_self_hosted_models_url, notice: _("Self-Hosted Model was created")
        else
          render :new
        end
      end

      def edit
        @self_hosted_model = ::Ai::SelfHostedModel.find(params[:id])
      end

      def update
        @self_hosted_model = ::Ai::SelfHostedModel.find(params[:id])

        result = ::Ai::SelfHostedModels::UpdateService.new(
          @self_hosted_model, current_user, update_self_hosted_model_params
        ).execute

        if result.success?
          redirect_to admin_ai_self_hosted_models_url, notice: _("Self-Hosted Model was updated")
        else
          render :edit
        end
      end

      def destroy
        @self_hosted_model = ::Ai::SelfHostedModel.find(params[:id])

        result = ::Ai::SelfHostedModels::DestroyService.new(@self_hosted_model, current_user).execute

        if result.success?
          redirect_to admin_ai_self_hosted_models_url, notice: _("Self-Hosted Model was deleted")
        else
          render :index
        end
      end

      private

      def ensure_registration!
        return if ::Ai::TestingTermsAcceptance.has_accepted?

        redirect_to admin_ai_terms_and_conditions_url
      end

      def update_self_hosted_model_params
        update_params = self_hosted_models_params
        api_token = update_params[:api_token]

        return update_params.except(:api_token) if api_token == ApplicationSetting::MASK_PASSWORD

        update_params
      end

      def self_hosted_models_params
        params.require(:self_hosted_model).permit(:name, :model, :endpoint, :api_token)
      end

      def ensure_feature_enabled!
        render_404 unless Feature.enabled?(:ai_custom_model) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
        render_404 unless Ability.allowed?(current_user, :manage_ai_settings)
      end
    end
  end
end
