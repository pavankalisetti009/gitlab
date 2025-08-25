# frozen_string_literal: true

module Ai
  module Catalog
    module DuoWorkflowPayloadBuilder
      class Base
        include Gitlab::Utils::StrongMemoize
        include ActiveModel::Model

        def initialize(flow, pinned_version_prefix = nil)
          @flow = flow
          @pinned_version_prefix = pinned_version_prefix
        end

        def build
          validate_inputs!
          build_flow_config
        end

        private

        attr_reader :flow, :pinned_version_prefix

        def validate_inputs!
          raise ArgumentError, 'Flow is required' if flow.nil?
          raise ArgumentError, 'Flow must be an Ai::Catalog::Item' unless flow.is_a?(::Ai::Catalog::Item)
          raise ArgumentError, 'Flow must have item_type of flow' unless flow.flow?
        end

        def pinned_to_specific_version?
          # if the flow is pinned to a specific version, we pin all agent versions too
          pinned_version_prefix.to_s.count('.') == 2
        end

        def flow_definition
          flow.definition(pinned_version_prefix)
        end
        strong_memoize_attr :flow_definition

        def steps
          flow_definition.steps
        end

        def step_unique_identifier(step)
          step[:unique_id]
        end
      end
    end
  end
end
