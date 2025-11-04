# frozen_string_literal: true

module Ai
  module Catalog
    # Finds AI catalog items for a specific project
    #
    # Arguments:
    #   current_user - User performing the search (required for feature flag and permission checks)
    #   project - Project to find AI catalog items for
    #   params - Hash containing search parameters:
    #     :all_available - Boolean, when true includes public items from the project's organization
    #     :item_types - Array of item types to filter by. E.g.: ['agent', 'flow']
    #     :enabled - Boolean, filters items by their enabled state in the project:
    #                - true: returns only enabled items
    #                - false: returns only disabled items
    #                - nil/blank: returns all items regardless of enabled state
    #     :search - String to search for in item name and description
    #
    # Returns ActiveRecord::Relation
    class ProjectItemsFinder
      def initialize(current_user, project, params: {})
        @current_user = current_user
        @project = project
        @params = params
      end

      def execute
        return Item.none unless Feature.enabled?(:global_ai_catalog, current_user)
        return Item.none unless Ability.allowed?(current_user, :developer_access, project)

        items = init_collection
        items = by_item_type(items)
        items = by_enabled_state(items)
        by_search(items)
      end

      private

      attr_reader :current_user, :project, :params

      def init_collection
        items = Item.not_deleted.for_project(project)
        items = items.or(Item.not_deleted.for_organization(project.organization).public_only) if params[:all_available]
        items.order_by_id_desc
      end

      def by_item_type(items)
        return items if params[:item_types].blank?

        items.with_item_type(params[:item_types])
      end

      def by_enabled_state(items)
        return items if params[:enabled].nil?

        enabled_items = project.configured_ai_catalog_items.by_enabled(true)

        if params[:enabled]
          items.id_in(enabled_items.select(:ai_catalog_item_id))
        else
          items.id_not_in(enabled_items.select(:ai_catalog_item_id))
        end
      end

      def by_search(items)
        return items if params[:search].blank?

        items.search(params[:search])
      end
    end
  end
end
