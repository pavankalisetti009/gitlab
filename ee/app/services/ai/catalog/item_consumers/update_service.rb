# frozen_string_literal: true

module Ai
  module Catalog
    module ItemConsumers
      class UpdateService
        include EventsTracking
        include Gitlab::Utils::StrongMemoize

        def initialize(item_consumer, current_user, params)
          @current_user = current_user
          @item_consumer = item_consumer
          @params = params.slice(:pinned_version_prefix)
        end

        def execute
          return error_no_permissions unless allowed?
          return validation_error if validation_error&.error?

          if item_consumer.update(params)
            track_item_consumer_event(item_consumer, 'update_ai_catalog_item_consumer')
            ServiceResponse.success(payload: { item_consumer: item_consumer })
          else
            error_updating
          end
        end

        private

        attr_reader :current_user, :item_consumer, :params

        def allowed?
          Ability.allowed?(current_user, :admin_ai_catalog_item_consumer, item_consumer)
        end

        def error_no_permissions
          error('You have insufficient permission to update this item consumer')
        end

        # TODO refactor these validations into the `ItemConsumer` model
        # https://gitlab.com/gitlab-org/gitlab/-/issues/581655
        def validation_error
          return unless params.key?(:pinned_version_prefix)

          return error_pinned_version_prefix_format unless params[:pinned_version_prefix].to_s.count('.') == 2

          if resolved_version.nil? || resolved_version != item_consumer.item.latest_released_version_with_fallback
            error_version_is_not_latest
          end
        end
        strong_memoize_attr :validation_error

        def error_pinned_version_prefix_format
          error('pinned_version_prefix is not a valid version string')
        end

        def error_version_is_not_latest
          error('pinned_version_prefix must resolve to the latest released version of the item')
        end

        def error(message)
          ServiceResponse.error(payload: { item_consumer: item_consumer }, message: Array(message))
        end

        def error_updating
          error(item_consumer.errors.full_messages.presence || 'Failed to update item consumer')
        end

        def resolved_version
          @resolved_version ||= item_consumer.item.resolve_version(params[:pinned_version_prefix])
        end
      end
    end
  end
end
