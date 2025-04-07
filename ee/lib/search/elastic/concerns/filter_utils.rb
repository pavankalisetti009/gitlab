# frozen_string_literal: true

module Search
  module Elastic
    module Concerns
      module FilterUtils
        extend ActiveSupport::Concern
        # This is a helper method that we are using to add filter conditions
        # in this method we are skipping all blank hashes and we can use it for adding nested filter conditions.
        # `path` is a sequence of key objects (Hash#dig syntax). The value by that path should be an array.
        def add_filter(query_hash, *path)
          filter_result = yield

          return query_hash if filter_result.blank?

          query_hash.dig(*path) << filter_result
          query_hash
        end
      end
    end
  end
end
