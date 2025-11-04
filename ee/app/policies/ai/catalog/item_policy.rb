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

      condition(:project_ai_catalog_available, scope: :subject) do
        @subject.project && @subject.project.ai_catalog_available?
      end

      condition(:developer_access) do
        can?(:developer_access, @subject.project)
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

      rule { public_item | developer_access }.policy do
        enable :read_ai_catalog_item
      end

      rule { maintainer_access }.policy do
        enable :admin_ai_catalog_item # (Create and update)
        enable :delete_ai_catalog_item
      end

      rule { admin }.policy do
        enable :force_hard_delete_ai_catalog_item
      end

      rule { ~ai_catalog_enabled & ~admin }.policy do
        prevent :read_ai_catalog_item
        prevent :admin_ai_catalog_item
        prevent :delete_ai_catalog_item
      end

      rule { deleted_item & ~admin }.policy do
        prevent :admin_ai_catalog_item
        prevent :delete_ai_catalog_item
      end

      rule { ~public_item & ~project_ai_catalog_available & ~admin }.policy do
        prevent :read_ai_catalog_item
      end

      rule { ~project_ai_catalog_available & ~admin }.policy do
        prevent :admin_ai_catalog_item
        prevent :delete_ai_catalog_item
      end

      rule { flow & ~flows_enabled & ~admin }.policy do
        prevent :read_ai_catalog_item
        prevent :admin_ai_catalog_item
        prevent :delete_ai_catalog_item
      end

      rule { third_party_flow & ~third_party_flows_enabled & ~admin }.policy do
        prevent :read_ai_catalog_item
        prevent :admin_ai_catalog_item
        prevent :delete_ai_catalog_item
      end
    end
  end
end
