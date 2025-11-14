# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class AuditEventMessageService
        def initialize(event_type, flow, params = {})
          @event_type = event_type
          @flow = flow
          @params = params
          @old_definition = params[:old_definition]
        end

        def messages
          case event_type
          when 'create_ai_catalog_flow'
            create_messages
          when 'update_ai_catalog_flow'
            update_messages
          when 'delete_ai_catalog_flow'
            delete_messages
          when 'enable_ai_catalog_flow'
            enable_messages
          when 'disable_ai_catalog_flow'
            disable_messages
          else
            []
          end
        end

        private

        attr_reader :event_type, :flow, :old_definition, :params

        def create_messages
          messages = []

          visibility = flow.public? ? 'public' : 'private'
          tools = extract_tools_from_definition(flow.latest_version.definition)

          if tools.present?
            tools_list = format_list(tools)
            messages << "Created a new #{visibility} AI flow with tools: #{tools_list}"
          else
            messages << "Created a new #{visibility} AI flow with no tools"
          end

          messages << version_message(flow.latest_version)

          messages
        end

        def update_messages
          messages = []

          change_descriptions = build_change_descriptions
          messages << "Updated AI flow: #{change_descriptions.join(', ')}" if change_descriptions.any?

          messages << visibility_change_message if visibility_changed?

          messages << version_message(flow.latest_version) if version_created_or_released?

          messages << 'Updated AI flow' if messages.empty?

          messages
        end

        def delete_messages
          ['Deleted AI flow']
        end

        def enable_messages
          scope = params[:scope] || 'project/group'
          ["Enabled AI flow for #{scope}"]
        end

        def disable_messages
          scope = params[:scope] || 'project/group'
          ["Disabled AI flow for #{scope}"]
        end

        def build_change_descriptions
          descriptions = []

          old_def, new_def = get_definition_comparison
          return descriptions unless old_def && new_def

          descriptions.concat(tools_changes(old_def, new_def))
          descriptions.concat(prompts_changes(old_def, new_def))
          descriptions.concat(routes_changes(old_def, new_def))
          descriptions.concat(entry_point_changes(old_def, new_def))
          descriptions.concat(components_changes(old_def, new_def))
          descriptions.concat(environment_changes(old_def, new_def))
          descriptions.concat(version_changes(old_def, new_def))

          descriptions
        end

        def tools_changes(old_def, new_def)
          changes = []
          old_tools = extract_tools_from_definition(old_def)
          new_tools = extract_tools_from_definition(new_def)
          tools_added = new_tools - old_tools
          tools_removed = old_tools - new_tools

          changes << "Added tools: #{format_list(tools_added)}" if tools_added.any?
          changes << "Removed tools: #{format_list(tools_removed)}" if tools_removed.any?

          changes
        end

        def prompts_changes(old_def, new_def)
          changes = []
          old_prompts = extract_prompts_from_definition(old_def)
          new_prompts = extract_prompts_from_definition(new_def)
          prompts_added = new_prompts.keys - old_prompts.keys
          prompts_removed = old_prompts.keys - new_prompts.keys
          prompts_modified = (old_prompts.keys & new_prompts.keys).select do |key|
            old_prompts[key] != new_prompts[key]
          end

          changes << "Modified prompts: #{format_list(prompts_modified)}" if prompts_modified.any?
          changes << "Added prompts: #{format_list(prompts_added)}" if prompts_added.any?
          changes << "Removed prompts: #{format_list(prompts_removed)}" if prompts_removed.any?

          changes
        end

        def routes_changes(old_def, new_def)
          changes = []
          old_routes = extract_routes_from_definition(old_def)
          new_routes = extract_routes_from_definition(new_def)
          routes_added = new_routes - old_routes
          routes_removed = old_routes - new_routes

          changes << "Added routes: #{format_list(routes_added)}" if routes_added.any?
          changes << "Removed routes: #{format_list(routes_removed)}" if routes_removed.any?

          changes
        end

        def entry_point_changes(old_def, new_def)
          old_entry_point = old_def.dig('flow', 'entry_point')
          new_entry_point = new_def.dig('flow', 'entry_point')

          return [] if old_entry_point == new_entry_point
          return [] unless old_entry_point.present? && new_entry_point.present?

          ["Entry point changed from '#{old_entry_point}' to '#{new_entry_point}'"]
        end

        def components_changes(old_def, new_def)
          changes = []
          old_components = extract_component_names(old_def)
          new_components = extract_component_names(new_def)
          components_added = new_components - old_components
          components_removed = old_components - new_components

          changes << "Added components: #{format_list(components_added)}" if components_added.any?
          changes << "Removed components: #{format_list(components_removed)}" if components_removed.any?

          changes
        end

        def environment_changes(old_def, new_def)
          old_environment = old_def['environment']
          new_environment = new_def['environment']

          return [] if old_environment == new_environment
          return [] unless old_environment.present? && new_environment.present?

          ["Environment changed from '#{old_environment}' to '#{new_environment}'"]
        end

        def version_changes(old_def, new_def)
          old_version = old_def['version']
          new_version = new_def['version']

          return [] if old_version == new_version
          return [] unless old_version.present? && new_version.present?

          ["Version changed from '#{old_version}' to '#{new_version}'"]
        end

        def get_definition_comparison
          [old_definition, flow.latest_version.definition]
        end

        def visibility_changed?
          visibility_change.present? && visibility_change[0] != visibility_change[1]
        end

        def visibility_change_message
          if visibility_change[1] == true
            'Made AI flow public'
          else
            'Made AI flow private'
          end
        end

        def visibility_change
          flow.previous_changes['public']
        end

        def version_created_or_released?
          version_changes = flow.latest_version.previous_changes
          version_changes.key?('id') || version_changes.key?('release_date')
        end

        def version_message(version)
          if version.draft?
            "Created new draft version #{version.version} of AI flow"
          else
            "Released version #{version.version} of AI flow"
          end
        end

        def extract_tools_from_definition(definition)
          return [] unless definition

          components = definition['components'] || []
          tools = []

          components.each do |component|
            component_tools = component['toolset'] || []
            tools.concat(component_tools)

            tool_name = component['tool_name']
            tools << tool_name if tool_name.present?
          end

          tools.uniq
        end

        def extract_prompts_from_definition(definition)
          return {} unless definition

          prompts = definition['prompts'] || []
          prompts.index_by { |prompt| prompt['prompt_id'] }
        end

        def extract_routes_from_definition(definition)
          return [] unless definition

          routers = definition['routers'] || []
          routes = []

          routers.each do |router|
            from = router['from']
            to = router['to']

            if to.present?
              routes << "#{from} → #{to}"
            elsif router['condition'].present?
              condition_routes = router.dig('condition', 'routes') || {}
              condition_routes.each_value do |target|
                routes << "#{from} → #{target}"
              end
            end
          end

          routes.uniq
        end

        def extract_component_names(definition)
          return [] unless definition

          components = definition['components'] || []
          components.filter_map { |component| component['name'] }
        end

        def format_list(items)
          return '[]' if items.blank?

          "[#{items.join(', ')}]"
        end
      end
    end
  end
end
