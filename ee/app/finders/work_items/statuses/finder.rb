# frozen_string_literal: true

module WorkItems
  module Statuses
    class Finder
      attr_reader :namespace, :params, :current_user

      def initialize(namespace, params = {}, current_user = nil)
        @namespace = namespace
        @params = params
        @current_user = current_user
      end

      def execute
        result = if params.key?('system_defined_status_identifier')
                   find_system_defined_status_by_id
                 elsif params.key?('custom_status_id')
                   find_custom_status_by_id
                 elsif params.key?('name')
                   name = params['name']
                   find_status_by_name(name).presence || find_status_without_quotes(name)
                 end

        Array(result)
      end

      def find_single_status
        execute.first
      end

      private

      def find_system_defined_status_by_id
        ::WorkItems::Statuses::SystemDefined::Status
          .find_by(id: params['system_defined_status_identifier'].to_i) # rubocop: disable CodeReuse/ActiveRecord -- this is a fixed model
      end

      def find_custom_status_by_id
        ::WorkItems::Statuses::Custom::Status
          .in_namespace(namespace)
          .find_by_id(params['custom_status_id'])
      end

      def find_status_without_quotes(name)
        return unless name.include?('"')
        return unless name.start_with?('"') && name.end_with?('"') && name.length > 2

        # Remove only leading and trailing quotes, not quotes within the name and
        # avoid regexp usage and ReDoS attacks with this approach.
        find_status_by_name(name[1..-2])
      end

      def find_status_by_name(name)
        return [] if name.blank?

        namespace ? find_status_in_namespace(name) : find_statuses_across_namespaces(name)
      end

      def find_status_in_namespace(name)
        status = if namespace&.custom_statuses&.exists?
                   ::WorkItems::Statuses::Custom::Status.find_by_namespace_and_name(namespace, name)
                 else
                   ::WorkItems::Statuses::SystemDefined::Status.find_by_name(name)
                 end

        Array(status)
      end

      def find_statuses_across_namespaces(name)
        return [] unless current_user

        group_ids = current_user.authorized_root_ancestor_ids
        return [] if group_ids.empty?

        custom_statuses = ::WorkItems::Statuses::Custom::Status.find_by_name_across_namespaces(name, group_ids)

        statuses = custom_statuses.to_a

        system_defined_status = ::WorkItems::Statuses::SystemDefined::Status.find_by_name(name)
        statuses << system_defined_status if system_defined_status

        statuses
      end
    end
  end
end
