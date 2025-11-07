# frozen_string_literal: true

module Types
  module PermissionTypes
    module Ai
      module Catalog
        class Item < BasePermissionType
          graphql_name 'AiCatalogItemPermissions'
          description 'Check permissions for the current user on an AI catalog item.'

          abilities :read_ai_catalog_item, :admin_ai_catalog_item, :report_ai_catalog_item
        end
      end
    end
  end
end
