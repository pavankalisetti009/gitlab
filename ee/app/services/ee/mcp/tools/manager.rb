# frozen_string_literal: true

module EE
  module Mcp
    module Tools
      module Manager
        extend ::Gitlab::Utils::Override

        # Registry of all EE custom tools mapped to their service classes
        EE_CUSTOM_TOOLS = {
          'semantic_code_search' => ::Mcp::Tools::SearchCodebaseService
        }.freeze

        override :get_tool
        def get_tool(name:, version: nil)
          if version && !validate_semantic_version(version)
            raise ::Mcp::Tools::Manager::InvalidVersionFormatError, version
          end

          return get_ee_custom_tool(name, version) if EE_CUSTOM_TOOLS.key?(name)

          super
        end

        override :build_tools
        def build_tools
          ce_tools = super
          ee_tools = build_ee_tools
          { **ce_tools, **ee_tools }
        end

        private

        def get_ee_custom_tool(name, version)
          tool_class = EE_CUSTOM_TOOLS[name]

          unless version.nil? || tool_class.version_exists?(version)
            available_versions = tool_class.available_versions
            raise ::Mcp::Tools::Manager::VersionNotFoundError.new(name, version, available_versions)
          end

          tool_class.new(name: name, version: version)
        end

        def build_ee_tools
          tools = {}

          # Build EE custom tools using their latest versions
          EE_CUSTOM_TOOLS.each do |name, tool_class|
            tools[name] = tool_class.new(name: name)
          end

          tools
        end
      end
    end
  end
end
