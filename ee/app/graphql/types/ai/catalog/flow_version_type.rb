# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      # rubocop: disable Graphql/AuthorizeTypes -- Permissions are still to be determined https://gitlab.com/gitlab-org/gitlab/-/issues/553928
      class FlowVersionType < ::Types::BaseObject
        graphql_name 'AiCatalogFlowVersion'
        description 'An AI catalog flow version'

        implements ::Types::Ai::Catalog::VersionInterface
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
