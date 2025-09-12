# frozen_string_literal: true

module Ai
  module Catalog
    module Concerns
      module FlowVersion
        extend ActiveSupport::Concern

        included do
          def delete_no_longer_used_dependencies
            dependencies.where.not(dependency_id: dependency_ids).delete_all
          end

          def dependency_ids
            # Check to ensure item is a flow and not an agent, so we don't have to load item for item.flow?
            return unless definition['steps']

            definition['steps'].pluck('agent_id').uniq.compact # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- Not ActiveRecord
          end
        end
      end
    end
  end
end
