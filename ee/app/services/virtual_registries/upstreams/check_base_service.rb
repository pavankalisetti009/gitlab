# frozen_string_literal: true

module VirtualRegistries
  module Upstreams
    class CheckBaseService
      ERRORS = ::VirtualRegistries::BaseService::BASE_ERRORS.merge(
        file_not_found_on_upstreams: ServiceResponse.error(
          message: 'File not found on any upstream',
          reason: :file_not_found_on_upstreams
        )
      ).freeze

      NETWORK_TIMEOUT = ::VirtualRegistries::BaseService::NETWORK_TIMEOUT

      def initialize(upstreams:, params: {})
        @upstreams = upstreams
        @params = params
        @results = Array.new(upstreams.size)
      end

      def execute
        return ERRORS[:path_not_present] unless path.present?
        return ERRORS[:file_not_found_on_upstreams] unless upstreams.any?

        check
      end

      private

      attr_reader :upstreams, :params, :results

      def path
        params[:path]
      end
    end
  end
end
