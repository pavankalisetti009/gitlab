# frozen_string_literal: true

module EE
  module Resolvers
    module AutocompleteUsersResolver # rubocop:disable Gitlab/BoundedContexts -- EE extension of CE AutocompleteUsersResolver
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        argument :include_service_accounts_for_trigger_events, [::Types::Ai::FlowTrigger::EventTypeEnum],
          required: false,
          experiment: { milestone: '18.9' },
          description: 'Which flow triggers events associated to the service accounts to include.'
      end

      private

      override :finder_params
      def finder_params(args)
        super.merge(
          args.slice(:include_service_accounts_for_trigger_events)
        )
      end
    end
  end
end
