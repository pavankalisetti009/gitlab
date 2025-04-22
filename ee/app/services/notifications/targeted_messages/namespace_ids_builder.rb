# frozen_string_literal: true

require 'csv'

module Notifications
  module TargetedMessages
    class NamespaceIdsBuilder
      def initialize(file)
        @file = file
      end

      def build
        namespace_ids_from_file = parsed_namespace_ids
        valid_namespace_ids = Namespace.id_in(namespace_ids_from_file).ids # rubocop: disable CodeReuse/ActiveRecord -- we need to fetch ids
        @invalid_namespace_ids = namespace_ids_from_file - valid_namespace_ids

        {
          valid_namespace_ids: valid_namespace_ids,
          invalid_namespace_ids: invalid_namespace_ids,
          message: build_message,
          success: true
        }
      rescue StandardError => e
        message = format(
          s_('TargetedMessages|Failed to assign namespaces due to error processing CSV: %{error_message}'),
          error_message: e.message
        )

        {
          valid_namespace_ids: [],
          invalid_namespace_ids: [],
          message: message,
          success: false
        }
      end

      private

      attr_reader :file, :invalid_namespace_ids

      INVALID_ID_MESSAGE_LIMIT = 5
      private_constant :INVALID_ID_MESSAGE_LIMIT

      def build_message
        return unless invalid_namespace_ids.any?

        format(
          s_(
            'TargetedMessages|the following namespace ids were invalid and have been ignored: %{invalid_ids_message}'
          ),
          invalid_ids_message: concatenated_invalid_ids_msg
        )
      end

      def concatenated_invalid_ids_msg
        if invalid_namespace_ids.size <= INVALID_ID_MESSAGE_LIMIT
          invalid_namespace_ids.join(', ')
        else
          "#{invalid_namespace_ids.first(INVALID_ID_MESSAGE_LIMIT).join(', ')} and " \
            "#{invalid_namespace_ids.size - INVALID_ID_MESSAGE_LIMIT} more"
        end
      end

      def parsed_namespace_ids
        return [] if file.blank?

        namespace_ids = Set.new

        CSV.new(file.tempfile, headers: false).each do |row|
          id = Integer(row.first, exception: false)
          namespace_ids.add(id) if id
        end

        namespace_ids.to_a
      end
    end
  end
end
