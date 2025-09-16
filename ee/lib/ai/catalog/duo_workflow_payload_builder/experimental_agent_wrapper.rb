# frozen_string_literal: true

module Ai
  module Catalog
    module DuoWorkflowPayloadBuilder
      class ExperimentalAgentWrapper < Experimental
        include Gitlab::Utils::StrongMemoize
        extend ::Gitlab::Utils::Override

        override :initialize
        def initialize(flow, flow_version, params = {})
          @flow_version = flow_version
          @user_prompt_input = params[:user_prompt_input]
          super(flow, params[:pinned_version_prefix])
        end

        private

        attr_reader :flow_version, :user_prompt_input

        override :flow_definition
        def flow_definition
          ::Ai::Catalog::FlowDefinition.new(flow, flow_version)
        end
        strong_memoize_attr :flow_definition

        override :user_prompt
        def user_prompt(_definition)
          user_prompt_input
        end
      end
    end
  end
end
