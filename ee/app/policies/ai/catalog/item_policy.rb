# frozen_string_literal: true

module Ai
  module Catalog
    class ItemPolicy < ::BasePolicy
      condition(:ai_catalog_enabled, scope: :user) do
        ::Feature.enabled?(:global_ai_catalog, @user)
      end

      condition(:flows_enabled, scope: :user) do
        ::Feature.enabled?(:ai_catalog_flows, @user)
      end

      condition(:third_party_flows_enabled, scope: :user) do
        ::Feature.enabled?(:ai_catalog_third_party_flows, @user)
      end

      condition(:ai_catalog_available_for_user, scope: :user) do
        # Currently this maps to duo_agent_platform, but makes it easier to implement granular controls down the road
        # We could also add one for ai_catalog_flows, but since it's not granular if the user does not have access to
        # duo agent platform, they won't have access to anything
        # When anonymous user, delegates to the other setting controls.
        @user.nil? || @user.allowed_to_use_through_namespace?(:ai_catalog)
      end

      condition(:project_ai_catalog_available) do
        @subject.project && @subject.project.ai_catalog_available?
      end

      condition(:flows_available, scope: :subject) do
        @subject.project && ::Gitlab::Llm::StageCheck.available?(@subject.project, :ai_catalog_flows)
      end

      condition(:third_party_flows_available, scope: :subject) do
        @subject.project && ::Gitlab::Llm::StageCheck.available?(@subject.project, :ai_catalog_third_party_flows)
      end

      condition(:is_project_member) do
        @user && @subject.project&.member?(@user)
      end

      condition(:maintainer_access) do
        can?(:maintainer_access, @subject.project)
      end

      condition(:public_item, scope: :subject, score: 0) do
        @subject.public?
      end

      condition(:deleted_item, scope: :subject, score: 0) do
        @subject.deleted?
      end

      condition(:flow) do
        @subject.flow?
      end

      condition(:third_party_flow) do
        @subject.third_party_flow?
      end

      condition(:abuse_notification_email_present, scope: :global) do
        ::Gitlab::CurrentSettings.current_application_settings.abuse_notification_email.present?
      end

      condition(:can_admin_organization) do
        can?(:admin_organization, @subject.organization)
      end

      rule { public_item | is_project_member | can_admin_organization }.policy do
        enable :read_ai_catalog_item
        enable :report_ai_catalog_item
      end

      rule { maintainer_access }.policy do
        enable :admin_ai_catalog_item # (Create and update)
        enable :delete_ai_catalog_item
      end

      rule { admin }.policy do
        enable :force_hard_delete_ai_catalog_item
      end

      rule { anonymous | ~abuse_notification_email_present }.policy do
        prevent :report_ai_catalog_item
      end

      rule { ~ai_catalog_enabled & ~can_admin_organization }.policy do
        prevent :read_ai_catalog_item
        prevent :admin_ai_catalog_item
        prevent :delete_ai_catalog_item
        prevent :report_ai_catalog_item
      end

      rule { ~ai_catalog_available_for_user }.policy do
        prevent :read_ai_catalog_item
        prevent :admin_ai_catalog_item
        prevent :delete_ai_catalog_item
        prevent :report_ai_catalog_item
      end

      rule { deleted_item & ~can_admin_organization }.policy do
        prevent :admin_ai_catalog_item
        prevent :delete_ai_catalog_item
      end

      rule { ~public_item & ~project_ai_catalog_available & ~can_admin_organization }.policy do
        prevent :read_ai_catalog_item
        prevent :report_ai_catalog_item
      end

      rule { ~project_ai_catalog_available & ~can_admin_organization }.policy do
        prevent :admin_ai_catalog_item
        prevent :delete_ai_catalog_item
      end

      rule { flow & ~flows_enabled & ~can_admin_organization }.policy do
        prevent :read_ai_catalog_item
        prevent :admin_ai_catalog_item
        prevent :delete_ai_catalog_item
        prevent :report_ai_catalog_item
      end

      rule { flow & ~flows_available & ~can_admin_organization }.policy do
        prevent :admin_ai_catalog_item
        prevent :delete_ai_catalog_item
      end

      rule { flow & ~public_item & ~flows_available & ~can_admin_organization }.policy do
        prevent :read_ai_catalog_item
        prevent :report_ai_catalog_item
      end

      rule { third_party_flow & ~third_party_flows_enabled & ~can_admin_organization }.policy do
        prevent :read_ai_catalog_item
        prevent :admin_ai_catalog_item
        prevent :delete_ai_catalog_item
        prevent :report_ai_catalog_item
      end

      rule { third_party_flow & ~third_party_flows_available & ~can_admin_organization }.policy do
        prevent :admin_ai_catalog_item
        prevent :delete_ai_catalog_item
      end

      rule { third_party_flow & ~public_item & ~third_party_flows_available & ~can_admin_organization }.policy do
        prevent :read_ai_catalog_item
        prevent :report_ai_catalog_item
      end
    end
  end
end
