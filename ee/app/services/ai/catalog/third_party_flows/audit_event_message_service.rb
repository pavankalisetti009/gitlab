# frozen_string_literal: true

module Ai
  module Catalog
    module ThirdPartyFlows
      class AuditEventMessageService
        def initialize(event_type, third_party_flow, params = {})
          @event_type = event_type
          @third_party_flow = third_party_flow
          @params = params
          @old_definition = params[:old_definition]
        end

        def messages
          case event_type
          when 'create_ai_catalog_third_party_flow'
            create_messages
          when 'update_ai_catalog_third_party_flow'
            update_messages
          when 'delete_ai_catalog_third_party_flow'
            delete_messages
          when 'enable_ai_catalog_third_party_flow'
            enable_messages
          when 'disable_ai_catalog_third_party_flow'
            disable_messages
          else
            []
          end
        end

        private

        attr_reader :event_type, :third_party_flow, :old_definition, :params

        def create_messages
          messages = []

          visibility = third_party_flow.public? ? 'public' : 'private'
          messages << "Created a new #{visibility} AI external agent"

          messages << version_message(third_party_flow.latest_version)

          messages
        end

        def update_messages
          messages = []

          change_descriptions = build_change_descriptions
          messages << "Updated AI external agent: #{change_descriptions.join(', ')}" if change_descriptions.any?

          messages << visibility_change_message if visibility_changed?

          messages << version_message(third_party_flow.latest_version) if version_created_or_released?

          messages << 'Updated AI external agent' if messages.empty?

          messages
        end

        def delete_messages
          ['Deleted AI external agent']
        end

        def enable_messages
          scope = params[:scope] || 'project/group'
          ["Enabled AI external agent for #{scope}"]
        end

        def disable_messages
          scope = params[:scope] || 'project/group'
          ["Disabled AI external agent for #{scope}"]
        end

        def build_change_descriptions
          descriptions = []

          old_def, new_def = get_definition_comparison
          return descriptions unless old_def && new_def

          descriptions << 'Changed image' if old_def['image'] != new_def['image']
          descriptions << 'Changed commands' if old_def['commands'] != new_def['commands']
          descriptions << 'Changed variables' if old_def['variables'] != new_def['variables']

          if inject_gateway_token_changed?(old_def, new_def)
            descriptions << inject_gateway_token_change_message(new_def)
          end

          descriptions
        end

        def get_definition_comparison
          [old_definition, third_party_flow.latest_version.definition]
        end

        def visibility_changed?
          visibility_change.present? && visibility_change[0] != visibility_change[1]
        end

        def visibility_change_message
          if visibility_change[1] == true
            'Made AI external agent public'
          else
            'Made AI external agent private'
          end
        end

        def visibility_change
          third_party_flow.previous_changes['public']
        end

        def version_created_or_released?
          version_changes = third_party_flow.latest_version.previous_changes
          version_changes.key?('id') || version_changes.key?('release_date')
        end

        def version_message(version)
          if version.draft?
            "Created new draft version #{version.version} of AI external agent"
          else
            "Released version #{version.version} of AI external agent"
          end
        end

        def inject_gateway_token_changed?(old_def, new_def)
          old_def['injectGatewayToken'] != new_def['injectGatewayToken']
        end

        def inject_gateway_token_change_message(new_def)
          if new_def['injectGatewayToken']
            'Enabled AI Gateway token injection'
          else
            'Disabled AI Gateway token injection'
          end
        end
      end
    end
  end
end
