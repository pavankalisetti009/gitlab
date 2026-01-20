# frozen_string_literal: true

require_relative "../../code_reuse_helpers"

module RuboCop
  module Cop
    module API
      # Checks that API params using Procs in `values:` or `default:` have documentation.
      # Linter can be disabled with documentation: false
      #
      # @example
      #
      #   # bad (has Proc in values without documentation)
      #     params do
      #       requires :status, type: String, values: -> { Status.names }
      #     end
      #
      #   # bad (has Proc in default without documentation)
      #     params do
      #       optional :limit, type: Integer, default: -> { Config.default_limit }
      #     end
      #
      #   # good (has Proc with documentation)
      #     params do
      #       requires :status, type: String, values: -> { Status.names }, documentation: { example: 'active' }
      #       optional :limit, type: Integer, default: -> { Config.default_limit }, documentation: { example: 10 }
      #     end
      #
      #   # good (no Proc, documentation not required)
      #     params do
      #       requires :id, types: [String, Integer], desc: 'The ID of the project'
      #       optional :search, type: String, desc: 'Search string'
      #     end
      #
      #   # good (documentation explicitly disabled)
      #     params do
      #       requires :status, type: String, values: -> { Status.names }, documentation: false
      #     end
      #
      class ParameterDocumentation < RuboCop::Cop::Base
        include CodeReuseHelpers

        MSG_VALUES = "Parameter is constrained to a set of values determined at runtime. " \
          "Include a `documentation` field to inform about the allowed values as precisely as possible."
        MSG_DEFAULT = "Parameter has a default value determined at runtime. " \
          "Include a `documentation` field to inform about the default as precisely as possible."
        RESTRICT_ON_SEND = %i[requires optional].freeze

        PROC_PATTERN = "{(block (send nil? :proc) ...) (block (send nil? :lambda) ...) " \
          "(block (send (const nil? :Proc) :new) ...) (send nil? :proc) (send nil? :lambda) " \
          "(send _ :to_proc)}"

        # @!method has_documentation?(node)
        def_node_matcher :has_documentation?, <<~PATTERN
          (send _
            ...
            (hash <(pair (sym :documentation) _) ...>)
          )
        PATTERN

        # @!method proc_in_values?(node)
        def_node_matcher :proc_in_values?, <<~PATTERN
          (send _
            ...
            (hash <(pair (sym :values) #{PROC_PATTERN}) ...>)
          )
        PATTERN

        # @!method proc_in_default?(node)
        def_node_matcher :proc_in_default?, <<~PATTERN
          (send _
            ...
            (hash <(pair (sym :default) #{PROC_PATTERN}) ...>)
          )
        PATTERN

        def on_send(node)
          return if has_documentation?(node)

          if proc_in_values?(node)
            add_offense(node, message: MSG_VALUES)
          elsif proc_in_default?(node)
            add_offense(node, message: MSG_DEFAULT)
          end
        end
        alias_method :on_csend, :on_send
      end
    end
  end
end
