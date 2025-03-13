# frozen_string_literal: true

require 'csv'

module Notifications
  module TargetedMessages
    class ProcessCsvService
      def initialize(csv_file)
        @file = csv_file
      end

      def execute
        namespace_ids_from_file = parse_csv
        valid_namespace_ids = Namespace.id_in(namespace_ids_from_file).ids # rubocop: disable CodeReuse/ActiveRecord -- we need to fetch ids
        invalid_namespace_ids = namespace_ids_from_file - valid_namespace_ids

        ServiceResponse.success(payload: { valid_namespace_ids: valid_namespace_ids,
                                           invalid_namespace_ids: invalid_namespace_ids })
      rescue StandardError => e
        ServiceResponse.error(message: e.message)
      end

      private

      attr_reader :file

      def parse_csv
        namespace_ids = Set.new

        CSV.foreach(file.path, headers: false) do |row|
          id = Integer(row.first, exception: false)
          namespace_ids.add(id) if id
        end

        namespace_ids.to_a
      end
    end
  end
end
