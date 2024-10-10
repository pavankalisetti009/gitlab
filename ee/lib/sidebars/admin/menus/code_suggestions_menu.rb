# frozen_string_literal: true

module Sidebars
  module Admin
    module Menus
      class CodeSuggestionsMenu < ::Sidebars::Admin::BaseMenu
        override :link
        def link
          admin_gitlab_duo_seat_utilization_index_path
        end

        override :title
        def title
          s_('Admin|GitLab Duo')
        end

        override :sprite_icon
        def sprite_icon
          'tanuki-ai'
        end

        override :active_routes
        def active_routes
          { controller: :seat_utilization }
        end
      end
    end
  end
end
