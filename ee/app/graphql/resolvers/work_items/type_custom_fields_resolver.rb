# frozen_string_literal: true

module Resolvers
  module WorkItems
    class TypeCustomFieldsResolver < BaseResolver
      include LooksAhead

      type [Types::Issuables::CustomFieldType], null: true

      def resolve_with_lookahead
        custom_fields = ::Issuables::CustomFieldsFinder.new(
          current_user,
          group: context[:resource_parent].root_ancestor,
          active: true,
          work_item_type_ids: [object.work_item_type_id]
        ).execute

        apply_lookahead(custom_fields)
      end

      def unconditional_includes
        [:namespace]
      end

      def preloads
        {
          created_by: [:created_by],
          updated_by: [:updated_by],
          select_options: [:select_options],
          work_item_types: [:work_item_types]
        }
      end
    end
  end
end
