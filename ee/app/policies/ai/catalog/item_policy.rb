# frozen_string_literal: true

module Ai
  module Catalog
    class ItemPolicy < ::BasePolicy
      condition(:ai_catalog_enabled, scope: :user) do
        ::Feature.enabled?(:global_ai_catalog, @user)
      end

      condition(:public_item, scope: :subject) do
        @subject.public?
      end

      condition(:developer_access) do
        can?(:developer_access, @subject.project)
      end

      rule { public_item | developer_access }.policy do
        enable :read_ai_catalog_item
      end

      rule { ~ai_catalog_enabled }.policy do
        prevent :read_ai_catalog_item
      end
    end
  end
end
