# frozen_string_literal: true

module Ai
  module ActiveContext
    module Queries
      class Result < SimpleDelegator
        attr_reader :success, :hits, :error_code
        alias_method :success?, :success

        ERROR_NO_EMBEDDINGS = :no_embeddings

        def initialize(success:, hits: nil, error_code: nil)
          @success = success == true
          @hits = hits
          @error_code = error_code

          # Delegate all array methods to `hits`
          super(hits)
        end

        # privatize the `success` getter so `success?` will always be used
        private :success
      end
    end
  end
end
