# frozen_string_literal: true

module EE
  module Sidebars
    module Projects
      module Panel
        extend ::Gitlab::Utils::Override

        override :configure_menus
        def configure_menus
          super

          insert_menu_after(
            ::Sidebars::Projects::Menus::ProjectInformationMenu,
            onboarding_menu
          )

          if ::Sidebars::Projects::Menus::IssuesMenu.new(context).show_jira_menu_items?
            remove_menu(::Sidebars::Projects::Menus::ExternalIssueTrackerMenu)
          end

          if ::Sidebars::Projects::Menus::IssuesMenu.new(context).show_zentao_menu_items?
            remove_menu(::Sidebars::Projects::Menus::ZentaoMenu)
          end
        end

        private

        def onboarding_menu
          if ::Feature.enabled?(:learn_gitlab_redesign, context.project.namespace) && context.project.namespace.trial?
            ::Sidebars::Projects::Menus::GetStartedMenu.new(context)
          else
            ::Sidebars::Projects::Menus::LearnGitlabMenu.new(context)
          end
        end
      end
    end
  end
end
