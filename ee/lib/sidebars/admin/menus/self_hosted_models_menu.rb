# frozen_string_literal: true

module Sidebars
  module Admin
    module Menus
      class SelfHostedModelsMenu < ::Sidebars::Admin::BaseMenu
        override :link
        def link
          admin_ai_duo_self_hosted_path
        end

        override :title
        def title
          s_('Admin|GitLab Duo Self-Hosted')
        end

        override :sprite_icon
        def sprite_icon
          'machine-learning'
        end

        override :active_routes
        def active_routes
          { controller: :duo_self_hosted }
        end
      end
    end
  end
end
