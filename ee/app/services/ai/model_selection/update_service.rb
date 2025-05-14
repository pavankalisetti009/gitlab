# frozen_string_literal: true

module Ai
  module ModelSelection
    class UpdateService
      def initialize(feature_setting, user, params)
        @feature_setting = feature_setting
        @user = user
        @params = params
        @selection_scope = feature_setting.model_selection_scope
      end

      def execute
        unless Feature.enabled?(:ai_model_switching, selection_scope)
          return ServiceResponse.error(payload: nil,
            message: 'Contact your admin to enable the feature flag for AI Model Switching')
        end

        update_params = { offered_model_ref: params[:offered_model_ref] }

        fetch_model_definition = Ai::ModelSelection::FetchModelDefinitionsService
                                   .new(user, model_selection_scope: selection_scope)
                                   .execute

        return ServiceResponse.error(message: fetch_model_definition.message) if fetch_model_definition.error?

        update_params[:model_definitions] = fetch_model_definition.payload

        if feature_setting.update(update_params)
          ServiceResponse.success(payload: feature_setting)
        else
          ServiceResponse.error(payload: feature_setting,
            message: feature_setting.errors.full_messages.join(", "))
        end
      end

      private

      attr_accessor :feature_setting, :user, :selection_scope, :params
    end
  end
end
