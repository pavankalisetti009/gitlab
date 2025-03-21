# frozen_string_literal: true

module Gitlab
  module CodeOwners
    module OwnerValidation
      class Process
        include ::Gitlab::Utils::StrongMemoize

        # Maxmimum number of reference_extractor to validate
        # This maximum is currently not based on any benchmark
        MAX_REFERENCES = 200

        def initialize(project, file, max_references_limit: MAX_REFERENCES)
          @project = project
          @file = file
          @max_references_limit = max_references_limit
          @entries = file.parsed_data.values.flat_map(&:values)
        end

        def execute; end

        private

        attr_reader :project, :file, :max_references_limit, :entries
      end
    end
  end
end
