# frozen_string_literal: true

module EE
  module Mcp
    module Tools
      module Manager
        extend ::Gitlab::Utils::Override

        EE_CUSTOM_TOOLS = {
          'get_code_context' => ::Mcp::Tools::SearchCodebaseService.new(name: 'get_code_context')
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
