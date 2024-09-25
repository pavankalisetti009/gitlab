# frozen_string_literal: true

module Gitlab
  module Duo
    module Chat
      module AgentEvents
        class Error < BaseEvent
          def message
            data["message"]
          end
        end
      end
    end
  end
end
