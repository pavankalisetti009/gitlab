# frozen_string_literal: true

module Ai
  module AiResource
    class BaseAiResource
      attr_reader :resource, :current_user

      def initialize(user, resource)
        @resource = resource
        @current_user = user
      end

      def serialize_for_ai(_content_limit:)
        raise NotImplementedError
      end
    end
  end
end
