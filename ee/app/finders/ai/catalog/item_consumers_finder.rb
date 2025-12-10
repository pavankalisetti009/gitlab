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
        by_item_type(consumers)
      end

      private

      attr_reader :current_user, :params

      def validate_args!
        case params.values_at(:project_id, :group_id).compact.count
        when 0
          raise ArgumentError, 'Must provide either project_id or group_id param'
        when 2
          params.delete(:group_id)
        end
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
        params.fetch(:include_inherited, false)
      end
      strong_memoize_attr :include_inherited?

      def by_item(consumers)
        consumers.for_item(item_id)
      end

      def by_item_type(consumers)
        filtered_types = get_filtered_item_types

        return consumers if filtered_types == all_types

        consumers.with_item_type(filtered_types)
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

      def get_filtered_item_types
        types = (item_types.presence || all_types).map(&:to_sym)

        if Ability.allowed?(current_user, :read_ai_catalog_flow, container)
          types
        else
          types - [Ai::Catalog::Item::FLOW_TYPE]
        end
      end

      def all_types
        Ai::Catalog::Item.item_types.keys
      end
    end
  end
end
