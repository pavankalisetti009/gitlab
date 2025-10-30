# frozen_string_literal: true

module Groups
  module Settings
    module PackagesAndRegistries
      class VirtualRegistryCleanupPolicyController < Groups::ApplicationController
        layout 'group_settings'
        before_action :authorize_admin_group!

        before_action do
          render_404 unless ::Feature.enabled?(:ui_for_virtual_registry_cleanup_policy, group)

          render_404 unless ::VirtualRegistries::Packages::Maven.virtual_registry_available?(group, current_user,
            :admin_virtual_registry)

          @hide_search_settings = true
        end

        feature_category :virtual_registry
        urgency :low

        def index; end
      end
    end
  end
end
