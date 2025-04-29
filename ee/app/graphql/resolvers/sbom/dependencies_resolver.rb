# frozen_string_literal: true

module Resolvers
  module Sbom
    class DependenciesResolver < DependencyInterfaceResolver
      type Types::Sbom::DependencyType.connection_type, null: true

      private

      def dependencies(params)
        apply_lookahead(::Sbom::DependenciesFinder.new(object, params: mapped_params(params)).execute)
      end
    end
  end
end
