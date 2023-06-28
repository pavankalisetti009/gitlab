# frozen_string_literal: true

module RuboCop
  module Cop
    # Checks for usage of attr_encrypted
    # For more information see: https://gitlab.com/gitlab-org/gitlab/-/issues/26243
    #
    # @example
    #   # bad
    #   attr_encrypted :value
    #
    #   # good
    #   encrypts :value
    #
    class AttrEncrypted < RuboCop::Cop::Base
      MSG = "Do not use `attr_encrypted` to encrypt a column, as it's deprecated. Use `encrypts` which takes " \
        "advantage of Active Record Encryption: https://guides.rubyonrails.org/active_record_encryption.html"

      def_node_matcher :attr_encrypted?, <<~PATTERN
        (send nil? :attr_encrypted ...)
      PATTERN

      def on_send(node)
        return unless attr_encrypted?(node)

        add_offense(node)
      end
    end
  end
end
