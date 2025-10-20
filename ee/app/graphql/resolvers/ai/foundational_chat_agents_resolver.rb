# frozen_string_literal: true

module Resolvers
  module Ai
    class FoundationalChatAgentsResolver < BaseResolver
      description 'AI foundational chat agents.'

      type ::Types::Ai::FoundationalChatAgentType.connection_type, null: true

      argument :project_id, ::Types::GlobalIDType[Project],
        required: false,
        description: 'Global ID of the project where the chat is present.'

      argument :namespace_id, ::Types::GlobalIDType[::Namespace],
        required: false,
        description: 'Global ID of the namespace where the chat is present.'

      # rubocop:disable Lint/UnusedMethodArgument -- arguments will be used for feature flag managements
      def resolve(*, project_id: nil, namespace_id: nil)
        ::Ai::FoundationalChatAgent.all.sort_by(&:id)
      end
      # rubocop:enable Lint/UnusedMethodArgument
    end
  end
end
