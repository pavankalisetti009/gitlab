# frozen_string_literal: true

module Ai
  module Catalog
    class BaseService < ::BaseContainerService
      DEFAULT_VERSION = '1.0.0'

      def initialize(project:, current_user:, params: {})
        super(container: project, current_user: current_user, params: params)
      end

      private

      def allowed?
        Ability.allowed?(current_user, :admin_ai_catalog_item, project)
      end

      def error(message, payload: {})
        ServiceResponse.error(message: Array(message), payload: payload)
      end

      def error_no_permissions(payload: {})
        error('You have insufficient permissions', payload:)
      end
    end
  end
end
