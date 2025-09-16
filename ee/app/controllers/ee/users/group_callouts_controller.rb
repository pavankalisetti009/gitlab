# frozen_string_literal: true

module EE
  module Users
    module GroupCalloutsController
      extend ActiveSupport::Concern

      prepended do
        before_action :authorize_request!, only: :request_duo_agent_platform

        feature_category :activation, [:request_duo_agent_platform]
      end

      def request_duo_agent_platform
        response = ::Users::RecordAgentPlatformCalloutService.new(current_user: current_user, group: group).execute

        if response.success?
          head :ok
        else
          render json: { error: response.message }, status: :unprocessable_entity
        end
      end

      private

      def request_params
        params.permit(:namespace_id)
      end

      def authorize_request!
        render_404 unless can?(current_user, :read_namespace_via_membership, group)
      end

      def group
        @group ||= ::Group.find_by_id(request_params[:namespace_id])
      end
    end
  end
end
