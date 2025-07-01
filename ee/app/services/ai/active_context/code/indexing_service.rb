# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class IndexingService
        def self.execute(repository)
          new(repository).execute
        end

        def initialize(repository)
          @repository = repository
        end

        def execute
          repository.update!(state: :code_indexing_in_progress)
        end

        private

        attr_reader :repository
      end
    end
  end
end
