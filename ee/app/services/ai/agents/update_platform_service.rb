# frozen_string_literal: true

module Ai
  module Agents
    class UpdatePlatformService < BaseService
      def initialize(user, params)
        @current_user = user
        @params = params
      end

      def execute
        return unauthorized_response unless can_update?

        application_settings_result = update_application_settings # returns the updated record or false

        if perform_ai_settings_update? && application_settings_result
          @ai_settings_response = ::Ai::DuoSettings::UpdateService.new(
            duo_core_features_enabled: params[:duo_core_features_enabled]
          ).execute
        end

        if (ai_settings_response.nil? || ai_settings_response.success?) && application_settings_result
          ServiceResponse.success
        else
          log_error
          ServiceResponse.error(message: 'Failed to update Duo Agent Platform')
        end
      end

      private

      attr_reader :ai_settings_response

      def perform_ai_settings_update?
        !params[:duo_core_features_enabled].nil?
      end

      def update_application_settings
        ::ApplicationSettings::UpdateService.new(application_setting, current_user, application_setting_params).execute
      end

      def application_setting
        @application_setting ||= ApplicationSetting.current_without_cache
      end

      def application_setting_params
        params.slice(:instance_level_ai_beta_features_enabled, :duo_availability).compact
      end

      def can_update?
        Ability.allowed?(current_user, :admin_all_resources)
      end

      def unauthorized_response
        ServiceResponse.error(message: 'User not authorized to update Duo Agent Platform', reason: :access_denied)
      end

      def log_error
        error = StandardError.new(error_message)
        ::Gitlab::ErrorTracking.track_exception(error)
      end

      def error_message
        messages = []
        messages << ai_settings_response.message if ai_settings_response&.message
        messages += application_setting.errors.full_messages
        messages.join(', ')
      end
    end
  end
end
