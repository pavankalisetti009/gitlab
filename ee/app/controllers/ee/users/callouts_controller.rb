# frozen_string_literal: true

module EE
  module Users
    module CalloutsController
      extend ActiveSupport::Concern

      prepended do
        feature_category :activation, [:request_duo_agent_platform]
      end

      def request_duo_agent_platform
        response = ::Ai::Agents::UpdatePlatformRequestService.new(current_user).execute

        if response.success?
          head :ok
        else
          render json: { error: response.message }, status: :unprocessable_entity
        end
      end
    end
  end
end
