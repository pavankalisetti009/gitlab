# frozen_string_literal: true

module Ai
  module Catalog
    class ItemConsumersFinder
      include Gitlab::Utils::StrongMemoize

      def initialize(current_user, params: {})
        @current_user = current_user
        @params = params
      end

      def execute
        return none unless ::Feature.enabled?(:global_ai_catalog, current_user)

        validate_args!

        consumers = by_container
        consumers = with_parents(consumers) if container && include_inherited?
        consumers = by_item(consumers) if item_id
        consumers = with_item_type(consumers) if item_types.any?

        consumers
      end

      private

      attr_reader :current_user, :params

      def validate_args!
        required_param_present = params.values_at(:project_id, :group_id).compact.count == 1

        raise ArgumentError, 'Must provide either project_id or group_id param' unless required_param_present
      end

      def project_id
        params[:project_id]
      end

      def group_id
        params[:group_id]
      end

      def item_id
        params[:item_id]
      end

      def item_types
        [params[:item_type], *params[:item_types]].compact
      end

      def include_inherited?
        params.fetch(:include_inherited, true)
      end
      strong_memoize_attr :include_inherited?

      def by_item(consumers)
        consumers.for_item(item_id)
      end

      def with_item_type(consumers)
        consumers.with_item_type(item_types)
      end

      def none
        ItemConsumer.none
      end

      def container
        @container ||= project_id ? Project.find_by_id(project_id) : Group.find_by_id(group_id)
      end

      def by_container
        return none if container.nil?
        return none unless Ability.allowed?(current_user, :read_ai_catalog_item_consumer, container)

        container.configured_ai_catalog_items
      end

      def with_parents(consumers)
        current_container = container

        loop do
          current_container = current_container.parent
          return consumers if current_container.nil? || current_container.is_a?(Namespaces::UserNamespace)

          consumers = consumers.or(current_container.configured_ai_catalog_items)
        end
      end
    end
  end
end
