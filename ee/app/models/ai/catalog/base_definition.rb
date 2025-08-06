# frozen_string_literal: true

module Ai
  module Catalog
    class BaseDefinition
      def initialize(item, version)
        @item = item
        @version = version
      end

      def resolved_version
        @resolved_version ||= find_target_version
      end

      private

      attr_reader :item, :version

      def find_target_version
        # TODO: Implement custom version finding logic here

        find_latest_version
      end

      def find_latest_version
        item.latest_version
      end
    end
  end
end
