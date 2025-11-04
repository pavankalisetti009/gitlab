# frozen_string_literal: true

module EE
  module Nav
    module NewDropdownHelper
      extend ::Gitlab::Utils::Override

      private

      override :create_epic_menu_item
      def create_epic_menu_item(group)
        return if group&.work_items_consolidated_list_enabled?(current_user)

        if can?(current_user, :create_epic, group)
          ::Gitlab::Nav::TopNavMenuItem.build(
            id: 'create_epic',
            title: _('New epic'),
            href: new_group_epic_path(group),
            component: 'create_new_work_item_modal',
            data: {
              track_action: 'click_link_new_epic',
              track_label: 'plus_menu_dropdown',
              track_property: 'navigation_top'
            }
          )
        end
      end
    end
  end
end
