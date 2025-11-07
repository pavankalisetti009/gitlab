# frozen_string_literal: true

module EE
  module Mcp
    module Tools
      module GitlabSearchService
        extend ::Gitlab::Utils::Override

        private

        def advanced_search_enabled?
          ::Gitlab::CurrentSettings.elasticsearch_search?
        end

        def exact_code_search_enabled?
          ::Search::Zoekt.enabled?
        end
      end
    end
  end
end
