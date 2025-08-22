# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      module FlowHelper
        include Gitlab::Utils::StrongMemoize

        MAX_STEPS = 100

        private

        attr_accessor :steps_validation_errors

        def steps
          self.steps_validation_errors = []

          Array(params[:steps]).map.with_index do |step, index|
            agent = step[:agent]
            pinned_version_prefix = step[:pinned_version_prefix]
            next steps_validation_errors << "Step #{index + 1}: Invalid agent" unless agent.agent?

            current_version = agent.resolve_version(pinned_version_prefix)
            if current_version.nil?
              version_info = pinned_version_prefix ? " with prefix #{pinned_version_prefix}" : ''
              next steps_validation_errors << "Step #{index + 1}: Unable to resolve version#{version_info}"
            end

            {
              agent_id: agent.id,
              current_version_id: current_version.id,
              pinned_version_prefix: pinned_version_prefix
            }
          end.compact
        end
        strong_memoize_attr :steps

        def steps_valid?
          steps
          steps_validation_errors.empty?
        end

        def allowed?
          return false unless super
          return true if params[:steps].nil?

          params[:steps].all? { |step| Ability.allowed?(current_user, :read_ai_catalog_item, step[:agent]) }
        end

        def max_steps_exceeded?
          params[:steps] && params[:steps].count > MAX_STEPS
        end

        def error_max_steps
          error("Maximum steps for a flow (#{MAX_STEPS}) exceeded")
        end
      end
    end
  end
end
