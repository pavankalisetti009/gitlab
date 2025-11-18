# frozen_string_literal: true

module EE
  module Groups
    module Settings
      module PackagesAndRegistriesController
        extend ActiveSupport::Concern

        prepended do
          before_action only: :show do
            push_frontend_feature_flag(:ui_for_virtual_registry_cleanup_policy, group)
          end
        end
      end
    end
  end
end
