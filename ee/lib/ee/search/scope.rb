# frozen_string_literal: true

module EE
  module Search
    module Scope
      extend ActiveSupport::Concern

      ADVANCED_GLOBAL_SCOPES = %w[blobs commits epics notes wiki_blobs].freeze
      ZOEKT_GLOBAL_SCOPES = %w[blobs].freeze

      class_methods do
        extend ::Gitlab::Utils::Override

        private

        override :global_scopes
        def global_scopes
          enabled_scopes = super
          enabled_scopes += ADVANCED_GLOBAL_SCOPES if ::Gitlab::CurrentSettings.elasticsearch_search?
          enabled_scopes += ZOEKT_GLOBAL_SCOPES if ::Search::Zoekt.enabled?

          enabled_scopes.uniq
        end
      end
    end
  end
end
