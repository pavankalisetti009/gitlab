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
        consumers = by_foundational_flow_reference(consumers) if foundational_flow_reference
        consumers = by_configurable_for_project(consumers) if configurable_for_project_id
        consumers = by_item_type(consumers)
        consumers.order_by_catalog_priority
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

      def configurable_for_project_id
        params[:configurable_for_project_id]
      end

      def item_types
        [params[:item_type], *params[:item_types]].compact
      end

      def include_inherited?
        params.fetch(:include_inherited, false)
      end
      strong_memoize_attr :include_inherited?

      def foundational_flow_reference
        params[:foundational_flow_reference]
      end

      def by_item(consumers)
        consumers.for_item(item_id)
      end

      def by_item_type(consumers)
        filtered_types = get_filtered_item_types

        return consumers if filtered_types == all_types

        consumers.with_item_type(filtered_types)
      end

      def by_foundational_flow_reference(consumers)
        matching_item_ids = ::Ai::Catalog::Item
                              .with_foundational_flow_reference(foundational_flow_reference)
                              .select(:id)
        consumers.for_item(matching_item_ids)
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

        # (Foundational flows)
        if foundational_flow_reference.present?
          return [] unless Ability.allowed?(current_user, :read_ai_foundational_flow, container)
          return [] if beta_foundational_flow_without_beta_features?

          return [Ai::Catalog::Item::FLOW_TYPE]
        end

        # (Custom flows)
        if foundational_flow_reference.blank? && !Ability.allowed?(current_user, :read_ai_catalog_flow, container)
          types -= [Ai::Catalog::Item::FLOW_TYPE]
        end

        unless Ability.allowed?(current_user, :read_ai_catalog_third_party_flow, container)
          types -= [Ai::Catalog::Item::THIRD_PARTY_FLOW_TYPE]
        end

        types
      end

      def by_configurable_for_project(consumers)
        consumers.with_items_configurable_for_project(configurable_for_project_id)
      end

      def all_types
        Ai::Catalog::Item.item_types.keys
      end

      def beta_foundational_flow_without_beta_features?
        return false unless foundational_flow_reference.present?
        return false unless ::Ai::Catalog::FoundationalFlow.beta?(foundational_flow_reference)

        if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
          !container.root_ancestor.experiment_features_enabled
        else
          !::Gitlab::CurrentSettings.instance_level_ai_beta_features_enabled?
        end
      end
    end
  end
end
