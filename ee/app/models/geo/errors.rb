# frozen_string_literal: true

module Geo
  module Errors
    BaseError = Class.new(StandardError)
    class StatusTimeoutError < BaseError
      def message
        "Generating Geo node status is taking too long"
      end
    end

    class UnknownSelectiveSyncType < BaseError
      attr_reader :selective_sync_type

      def initialize(selective_sync_type:)
        @selective_sync_type = selective_sync_type
      end

      def message
        "Selective sync type is not known: #{selective_sync_type}"
      end
    end
  end
end
