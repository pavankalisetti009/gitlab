# frozen_string_literal: true

module Ai
  module Catalog
    class ItemsFinder
      def initialize(current_user, params: {})
        @current_user = current_user
        @params = params

        validate_organization!
      end

      def execute
        return Item.none unless ::Feature.enabled?(:global_ai_catalog, current_user)

        items = init_collection
        items = by_organization(items)
        items = by_project(items)
        items = by_item_type(items)
        items = by_id(items)
        by_search(items)
      end

      private

      attr_reader :current_user, :params

      def init_collection
        Item.not_deleted.public_or_visible_to_user(current_user).order_by_id_desc
      end

      def by_organization(items)
        return items unless params[:organization]

        items.for_organization(params[:organization])
      end

      def by_project(items)
        return items unless params[:project]

        items.for_project(params[:project])
      end

      def by_item_type(items)
        return items unless params[:item_type] || params[:item_types]

        items.with_item_type([params[:item_type], *params[:item_types]].compact)
      end

      def by_id(items)
        return items unless params[:id]

        items.id_in(params[:id])
      end

      def by_search(items)
        return items if params[:search].blank?

        items.search(params[:search])
      end

      def validate_organization!
        return if params[:organization].is_a?(::Organizations::Organization)

        raise ArgumentError, _('Organization parameter must be specified')
      end
    end
  end
end
