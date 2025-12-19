# frozen_string_literal: true

module Ai
  module Catalog
    module Items
      class BaseAuditEventMessageService
        def initialize(event_type, item, params = {})
          @event_type = event_type
          @item = item
          @params = params
          @old_definition = params[:old_definition]
        end

        def messages
          validate_schema_version!

          case event_type
          when "create_ai_catalog_#{item_type}"
            create_messages
          when "update_ai_catalog_#{item_type}"
            update_messages
          when "delete_ai_catalog_#{item_type}"
            delete_messages
          when "enable_ai_catalog_#{item_type}"
            enable_messages
          when "disable_ai_catalog_#{item_type}"
            disable_messages
          else
            []
          end
        end

        private

        attr_reader :event_type, :item, :old_definition, :params

        def item_type
          raise NotImplementedError, "#{self.class} must implement #item_type"
        end

        def item_type_label
          raise NotImplementedError, "#{self.class} must implement #item_type_label"
        end

        def expected_schema_version
          raise NotImplementedError, "#{self.class} must implement #expected_schema_version"
        end

        def validate_schema_version!
          return if item.blank? || item.latest_version.blank?

          actual_version = item.latest_version.schema_version
          expected_version = expected_schema_version

          return if actual_version == expected_version

          raise "Schema version mismatch for #{item_type_label}: expected #{expected_version}, " \
            "got #{actual_version}. Please update #{self.class} to handle the new schema version."
        end

        def create_messages
          raise NotImplementedError, "#{self.class} must implement #create_messages"
        end

        def update_messages
          messages = []

          change_descriptions = build_change_descriptions
          messages << "Updated #{item_type_label}: #{change_descriptions.join(', ')}" if change_descriptions.any?

          messages << visibility_change_message if visibility_changed?

          messages << version_message(item.latest_version) if version_created_or_released?

          messages << "Updated #{item_type_label}" if messages.empty?

          messages
        end

        def build_change_descriptions
          raise NotImplementedError, "#{self.class} must implement #build_change_descriptions"
        end

        def delete_messages
          ["Deleted #{item_type_label}"]
        end

        def enable_messages
          scope = params[:scope] || 'project/group'
          ["Enabled #{item_type_label} for #{scope}"]
        end

        def disable_messages
          scope = params[:scope] || 'project/group'
          ["Disabled #{item_type_label} for #{scope}"]
        end

        def get_definition_comparison
          [old_definition, item.latest_version.definition]
        end

        def visibility_changed?
          visibility_change.present? && visibility_change[0] != visibility_change[1]
        end

        def visibility_change_message
          if visibility_change[1] == true
            "Made #{item_type_label} public"
          else
            "Made #{item_type_label} private"
          end
        end

        def visibility_change
          item.previous_changes['public']
        end

        def version_created_or_released?
          version_changes = item.latest_version.previous_changes
          version_changes.key?('id') || version_changes.key?('release_date')
        end

        def version_message(version)
          if version.draft?
            "Created new draft version #{version.version} of #{item_type_label}"
          else
            "Released version #{version.version} of #{item_type_label}"
          end
        end

        def format_list(items)
          return '[]' if items.blank?

          "[#{items.join(', ')}]"
        end
      end
    end
  end
end
