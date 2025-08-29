# frozen_string_literal: true

module Search
  module Zoekt
    module Features
      class TraversalIdSearch < BaseFeature
        self.minimum_schema_version = 2531

        def preflight_checks_passed?
          Feature.enabled?(:zoekt_traversal_id_queries, user)
        end
      end
    end
  end
end
