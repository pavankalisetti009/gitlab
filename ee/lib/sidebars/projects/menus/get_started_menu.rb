# frozen_string_literal: true

module Sidebars # rubocop:todo Gitlab/BoundedContexts -- Existing namespace that should change as a coordinated effort.
  module Projects
    module Menus
      class GetStartedMenu < ::Sidebars::Menu
        override :link
        def link
          project_get_started_path(context.project)
        end

        override :active_routes
        def active_routes
          { controller: :get_started }
        end

        override :title
        def title
          _('Get started')
        end

        override :has_pill?
        def has_pill?
          true # since render checks if enabled, we can always set this as true
        end

        override :pill_count
        def pill_count
          percentage = ::Onboarding::Completion.new(
            context.project,
            context.current_user
          ).percentage

          "#{percentage}%"
        end

        override :sprite_icon
        def sprite_icon
          'bulb'
        end

        override :render?
        def render?
          context.learn_gitlab_enabled
        end

        override :serialize_as_menu_item_args
        def serialize_as_menu_item_args
          super.merge({
            sprite_icon: sprite_icon,
            pill_count: pill_count,
            has_pill: has_pill?,
            super_sidebar_parent: ::Sidebars::StaticMenu,
            item_id: :get_started
          })
        end
      end
    end
  end
end
