# frozen_string_literal: true

module EE
  module Groups
    module Settings
      module PackagesAndRegistriesController
        extend ActiveSupport::Concern

        prepended do
          before_action only: :show do
            push_frontend_feature_flag(:maven_virtual_registry, group)
            push_frontend_feature_flag(:ui_for_virtual_registry_cleanup_policy, group)
            push_licensed_feature(:packages_virtual_registry, group)
            push_frontend_ability(ability: :admin_virtual_registry,
              resource: group.virtual_registry_policy_subject, user: current_user)
          end
        end
      end
    end
  end
end
