# frozen_string_literal: true

module Ai
  module Catalog
    class ItemsFinder
      def initialize(current_user, params: {})
        @current_user = current_user
        @params = params
        @params[:organization] = current_user.organization if current_user
      end

      def execute
        return Item.none unless ::Feature.enabled?(:global_ai_catalog, current_user)

        items = init_collection
        items = by_organization(items)
        items = by_item_type(items)
        by_search(items)
      end

      private

      attr_reader :current_user, :params

      def init_collection
        Item.not_deleted.public_or_visible_to_user(current_user)
      end

      def by_organization(items)
        return items unless params[:organization]

        items.for_organization(params[:organization])
      end

      def by_item_type(items)
        return items unless params[:item_type]

        items.with_item_type(params[:item_type])
      end

      def by_search(items)
        return items if params[:search].blank?

        items.search(params[:search])
      end
    end
  end
end
