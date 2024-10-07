# frozen_string_literal: true

module API
  module Entities
    module Ai
      module DuoWorkflows
        class Event < Grape::Entity
          expose :id
          expose :event_type
          expose :event_status
          expose :message
        end
      end
    end
  end
end
