# frozen_string_literal: true

module Resolvers
  module Ai
    class FoundationalChatAgentsResolver < BaseResolver
      description 'AI foundational chat agents.'

      type ::Types::Ai::FoundationalChatAgentType.connection_type, null: true

      def resolve
        ::Ai::FoundationalChatAgent.all.sort_by(&:id)
      end
    end
  end
end
