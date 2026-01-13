# frozen_string_literal: true

module EE
  module Resolvers
    module AutocompleteUsersResolver # rubocop:disable Gitlab/BoundedContexts -- EE extension of CE AutocompleteUsersResolver
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        argument :hide_service_accounts_without_flow_triggers, GraphQL::Types::Boolean,
          required: false,
          default_value: false,
          experiment: { milestone: '18.8' },
          description: 'Whether or not to hide service accounts without an associated Duo flow trigger.'
      end

      private

      override :finder_params
      def finder_params(args)
        super.merge(
          args.slice(:hide_service_accounts_without_flow_triggers)
        )
      end
    end
  end
end
