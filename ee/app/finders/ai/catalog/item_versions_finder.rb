# frozen_string_literal: true

module Ai
  module Catalog
    class ItemVersionsFinder
      def initialize(current_user, params: {})
        @current_user = current_user
        @params = params

        validate_organization!
      end

      def execute
        return ItemVersion.none unless ::Feature.enabled?(:global_ai_catalog, current_user)

        versions = init_collection
        versions = by_organization(versions)
        versions = by_created_after(versions)
        versions.with_items.order_by_id_desc
      end

      private

      attr_reader :current_user, :params

      def init_collection
        # TODO: Extend to all items visible to the current_user https://gitlab.com/gitlab-org/gitlab/-/issues/584822
        ::Ai::Catalog::ItemVersion.for_public_items
      end

      def by_created_after(versions)
        return versions unless params[:created_after]

        versions.created_after(params[:created_after])
      end

      def by_organization(versions)
        versions.in_organization(params[:organization])
      end

      def validate_organization!
        return if params[:organization].is_a?(::Organizations::Organization)

        raise ArgumentError, _('Organization parameter must be specified')
      end
    end
  end
end
