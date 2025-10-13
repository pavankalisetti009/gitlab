# frozen_string_literal: true

module EE
  module Mcp
    module Tools
      module Manager
        extend ::Gitlab::Utils::Override

        EE_CUSTOM_TOOLS = {
          'semantic_code_search' => ::Mcp::Tools::SearchCodebaseService.new(name: 'semantic_code_search')
        }.freeze

        override :build_tools
        def build_tools
          ce_tools = super
          { **ce_tools, **EE_CUSTOM_TOOLS }
        end
      end
    end
  end
end
