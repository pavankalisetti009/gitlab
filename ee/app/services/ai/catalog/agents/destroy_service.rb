# frozen_string_literal: true

module Ai
  module Catalog
    module Agents
      class DestroyService < Ai::Catalog::Items::BaseDestroyService
        private

        def valid?
          super && item.agent?
        end

        def error_no_item
          error('Agent not found')
        end

        def track_deletion_audit_event
          send_audit_events('delete_ai_catalog_agent', item)
        end
      end
    end
  end
end
