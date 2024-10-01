# frozen_string_literal: true

module Resolvers
  module Issuables
    class CustomFieldsResolver < BaseResolver
      include LooksAhead

      type Types::Issuables::CustomFieldType.connection_type, null: true

      argument :active, GraphQL::Types::Boolean,
        required: false,
        description: 'Filter for active fields. If `false`, excludes active fields. ' \
          'If `true`, returns only active fields.'

      def resolve_with_lookahead(active: nil)
        custom_fields = ::Issuables::CustomFieldsFinder.new(current_user, group: object, active: active).execute

        offset_pagination(
          apply_lookahead(custom_fields)
        )
      end

      def unconditional_includes
        [:namespace]
      end

      def preloads
        {
          select_options: [:select_options],
          work_item_types: [:work_item_types]
        }
      end
    end
  end
end
