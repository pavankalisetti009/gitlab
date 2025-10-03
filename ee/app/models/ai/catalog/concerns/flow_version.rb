# frozen_string_literal: true

module Ai
  module Catalog
    module Concerns
      module FlowVersion
        extend ActiveSupport::Concern

        included do
          validate :validate_released_version_has_steps, if: -> { released? && flow? }

          def delete_no_longer_used_dependencies
            dependencies.where.not(dependency_id: dependency_ids).delete_all
          end

          def dependency_ids
            return unless flow? && definition['steps'].present?

            definition['steps'].pluck('agent_id').uniq.compact # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- Not ActiveRecord
          end

          def validate_released_version_has_steps
            return unless definition['steps'].empty?

            errors.add(:definition, s_('AICatalog|must have at least one node'))
          end
        end
      end
    end
  end
end
