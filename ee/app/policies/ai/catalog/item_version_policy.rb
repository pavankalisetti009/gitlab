# frozen_string_literal: true

module Ai
  module Catalog
    class ItemVersionPolicy < ::BasePolicy
      delegate { @subject.item }

      condition(:draft) do
        @subject.draft?
      end

      condition(:ai_catalog_enabled, scope: :user) do
        ::Feature.enabled?(:global_ai_catalog, @user)
      end

      condition(:project_ai_catalog_available) do
        @subject.project && @subject.project.ai_catalog_available?
      end

      condition(:developer_access) do
        can?(:developer_access, @subject.project)
      end

      condition(:maintainer_access) do
        can?(:maintainer_access, @subject.project)
      end

      rule { developer_access }.policy do
        enable :execute_ai_catalog_item_version
      end

      rule { ~maintainer_access & draft }.policy do
        prevent :execute_ai_catalog_item_version
      end

      rule { ~ai_catalog_enabled }.policy do
        prevent :execute_ai_catalog_item_version
      end

      rule { ~project_ai_catalog_available }.policy do
        prevent :execute_ai_catalog_item_version
      end
    end
  end
end
