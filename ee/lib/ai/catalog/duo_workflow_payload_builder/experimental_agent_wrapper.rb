# frozen_string_literal: true

module Ai
  module Catalog
    module DuoWorkflowPayloadBuilder
      class ExperimentalAgentWrapper < Experimental
        include Gitlab::Utils::StrongMemoize
        extend ::Gitlab::Utils::Override

        override :initialize
        def initialize(flow, flow_version, pinned_version_prefix = nil)
          @flow_version = flow_version
          super(flow, pinned_version_prefix)
        end

        private

        attr_reader :flow_version

        override :flow_definition
        def flow_definition
          ::Ai::Catalog::FlowDefinition.new(flow, flow_version)
        end
        strong_memoize_attr :flow_definition
      end
    end
  end
end
