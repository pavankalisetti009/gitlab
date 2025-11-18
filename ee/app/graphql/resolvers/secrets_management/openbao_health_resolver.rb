# frozen_string_literal: true

module Resolvers
  module SecretsManagement
    class OpenbaoHealthResolver < BaseResolver
      type GraphQL::Types::Boolean, null: false

      description 'Check if OpenBao instance is healthy and reachable'

      def resolve
        raise_resource_not_available_error! unless current_user

        # we don't need JWT here since the health endpoint from Openbao is public
        client = ::SecretsManagement::SecretsManagerClient.new(jwt: nil)
        client.check_health
      end
    end
  end
end
