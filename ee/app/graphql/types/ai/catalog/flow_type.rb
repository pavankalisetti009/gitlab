# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      # rubocop: disable Graphql/AuthorizeTypes -- Permissions are still to be determined https://gitlab.com/gitlab-org/gitlab/-/issues/553928
      class FlowType < ::Types::BaseObject
        graphql_name 'AiCatalogFlow'
        description 'An AI catalog flow'

        implements ::Types::Ai::Catalog::ItemInterface
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
