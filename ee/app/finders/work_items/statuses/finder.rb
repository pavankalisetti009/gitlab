# frozen_string_literal: true

module WorkItems
  module Statuses
    class Finder
      attr_reader :namespace, :params

      def initialize(namespace, params = {})
        @namespace = namespace
        @params = params
      end

      # rubocop: disable CodeReuse/ActiveRecord -- required for the finder
      def execute
        if params.key?('system_defined_status_identifier')
          ::WorkItems::Statuses::SystemDefined::Status
            .find_by(id: params['system_defined_status_identifier'].to_i)
        elsif params.key?('custom_status_id')
          ::WorkItems::Statuses::Custom::Status
            .where(namespace: namespace)
            .find_by(id: params['custom_status_id'])
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
