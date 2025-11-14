# frozen_string_literal: true

module Ai
  module Catalog
    module Agents
      class AuditEventMessageService
        TOOLS_ID_AND_NAME = Ai::Catalog::BuiltInTool::ITEMS.to_h { |item| [item[:id], item[:name]] }.freeze

        def initialize(event_type, agent, params = {})
          @event_type = event_type
          @agent = agent
          @params = params
          @old_definition = params[:old_definition]
        end

        def messages
          case event_type
          when 'create_ai_catalog_agent'
            create_messages
          when 'update_ai_catalog_agent'
            update_messages
          when 'delete_ai_catalog_agent'
            delete_messages
          when 'enable_ai_catalog_agent'
            enable_messages
          when 'disable_ai_catalog_agent'
            disable_messages
          else
            []
          end
        end

        private

        attr_reader :event_type, :agent, :old_definition, :params

        def create_messages
          messages = []

          visibility = agent.public? ? 'public' : 'private'
          tools = agent.latest_version.definition['tools'] || []

          if tools.present?
            tools_list = format_tools_list(tools)
            messages << "Created a new #{visibility} AI agent with tools: #{tools_list}"
          else
            messages << "Created a new #{visibility} AI agent with no tools"
          end

          messages << version_message(agent.latest_version)

          messages
        end

        def update_messages
          messages = []

          change_descriptions = build_change_descriptions
          messages << "Updated AI agent: #{change_descriptions.join(', ')}" if change_descriptions.any?

          messages << visibility_change_message if visibility_changed?

          messages << version_message(agent.latest_version) if version_created_or_released?

          messages << 'Updated AI agent' if messages.empty?

          messages
        end

        def delete_messages
          ['Deleted AI agent']
        end

        def enable_messages
          scope = params[:scope] || 'project/group'
          ["Enabled AI agent for #{scope}"]
        end

        def disable_messages
          scope = params[:scope] || 'project/group'
          ["Disabled AI agent for #{scope}"]
        end

        def build_change_descriptions
          descriptions = []

          old_def, new_def = get_definition_comparison
          return descriptions unless old_def && new_def

          old_tools = old_def['tools'] || []
          new_tools = new_def['tools'] || []
          tools_added = new_tools - old_tools
          tools_removed = old_tools - new_tools

          if tools_added.any?
            tools_list = format_tools_list(tools_added)
            descriptions << "Added tools: #{tools_list}"
          end

          if tools_removed.any?
            tools_list = format_tools_list(tools_removed)
            descriptions << "Removed tools: #{tools_list}"
          end

          descriptions << 'Changed system prompt' if old_def['system_prompt']&.strip != new_def['system_prompt']&.strip

          descriptions
        end

        def get_definition_comparison
          [old_definition, agent.latest_version.definition]
        end

        def visibility_changed?
          visibility_change.present? && visibility_change[0] != visibility_change[1]
        end

        def visibility_change_message
          if visibility_change[1] == true
            'Made AI agent public'
          else
            'Made AI agent private'
          end
        end

        def visibility_change
          agent.previous_changes['public']
        end

        def version_created_or_released?
          version_changes = agent.latest_version.previous_changes
          version_changes.key?('id') || version_changes.key?('release_date')
        end

        def version_message(version)
          if version.draft?
            "Created new draft version #{version.version} of AI agent"
          else
            "Released version #{version.version} of AI agent"
          end
        end

        def format_tools_list(tools)
          return '[]' if tools.blank?

          tool_names = tools.filter_map { |tool_id| TOOLS_ID_AND_NAME[tool_id] }

          "[#{tool_names.join(', ')}]"
        end
      end
    end
  end
end
