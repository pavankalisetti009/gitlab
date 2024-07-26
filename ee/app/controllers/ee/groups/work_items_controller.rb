# frozen_string_literal: true

module EE
  module Groups
    module WorkItemsController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      prepended do
        before_action :authorize_read_work_item!, only: [:description_diff, :delete_description_version]

        before_action do
          push_force_frontend_feature_flag(
            :work_items_rolledup_dates,
            group&.work_items_rolledup_dates_feature_flag_enabled?
          )
        end

        include DescriptionDiffActions
      end

      def show
        # Once we rollout epic work items, links to `/work_items/:iid` might be already used. However there could be the
        # scenario where we rollback the feature flag to enable epic work items. In this case, we want users to still
        # see their epics and therefore redirect them to `/epics/:iid`.
        return redirect_to group_epic_path(group, issuable.iid) if epic_work_item? && !namespace_work_items_enabled?

        super
      end

      private

      def issuable
        ::WorkItem.find_by_namespace_and_iid!(group, params[:iid])
      end
      strong_memoize_attr :issuable

      def epic_work_item?
        issuable.work_item_type == ::WorkItems::Type.default_by_type(:epic)
      end

      def authorize_read_work_item!
        access_denied! unless can?(current_user, :read_work_item, issuable)
      end
    end
  end
end
