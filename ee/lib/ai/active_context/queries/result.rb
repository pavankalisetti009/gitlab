# frozen_string_literal: true

module Ai
  module ActiveContext
    module Queries
      class Result
        include Enumerable

        NilHitsError = Class.new(StandardError)

        attr_reader :success, :hits, :error_code
        alias_method :success?, :success

        ERROR_NO_EMBEDDINGS = :no_embeddings

        ERROR_MESSAGE_TEMPLATE = {
          ERROR_NO_EMBEDDINGS => "%{target_class} '%{target_id}' has no embeddings"
        }.freeze

        def self.success(hits)
          new(success: true, hits: hits)
        end

        def self.error(error_code)
          new(success: false, error_code: error_code)
        end

        def self.no_embeddings_error
          error(ERROR_NO_EMBEDDINGS)
        end

        def initialize(success:, hits: nil, error_code: nil)
          @success = success == true
          @hits = hits
          @error_code = error_code
        end

        def error_message(target_class:, target_id:)
          return "Unknown error" unless error_code && ERROR_MESSAGE_TEMPLATE.key?(error_code)

          format(
            ERROR_MESSAGE_TEMPLATE[error_code],
            target_class: target_class,
            target_id: target_id
          )
        end

        def each(&block)
          unless hits
            raise(
              NilHitsError,
              "`hits` is nil. This is likely a failure result, please check `success?`"
            )
          end

          hits.each(&block)
        end

        # privatize the `success` getter so `success?` will always be used
        private :success
      end
    end
  end
end
