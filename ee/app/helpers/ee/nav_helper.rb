# frozen_string_literal: true

module EE
  module NavHelper
    extend ::Gitlab::Utils::Override

    override :extra_top_bar_classes
    def extra_top_bar_classes
      return unless top_bar_duo_button_enabled?

      'gl-group top-bar-duo-button-present'
    end

    def top_bar_duo_button_enabled?
      ::Gitlab::Llm::TanukiBot.show_breadcrumbs_entry_point?(user: current_user) && !project_studio_enabled?
    end

    override :page_has_markdown?
    def page_has_markdown?
      super || current_path?('epics#show')
    end

    override :admin_monitoring_nav_links
    def admin_monitoring_nav_links
      controllers = %w[audit_logs]
      super.concat(controllers)
    end
  end
end
