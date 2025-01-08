# frozen_string_literal: true

require_relative '../../migration_helpers'

module RuboCop
  module Cop
    module Migration
      # Cop that prevents introducing `encrypted_*` columns (used by the `attr_encrypted` gem).
      class PreventAddingAttrEncryptedColumns < RuboCop::Cop::Base
        include MigrationHelpers

        MSG = 'Do not introduce `%<wrong_column>s` (`attr_encrypted` column), introduce a single ' \
          '`%<correct_column>s` column with type `:jsonb` instead.'

        def_node_matcher :reverting?, <<~PATTERN
          (def :down ...)
        PATTERN

        def on_def(node)
          return unless in_migration?(node)

          # Don't enforce the rule when on down to keep consistency with existing schema
          return if reverting?(node)

          node.each_descendant(:send) do |send_node|
            wrong_column = attr_encrypted_wrong_column(send_node)
            next unless wrong_column

            correct_column = wrong_column.to_s.delete_prefix('encrypted_').delete_suffix('_iv')

            add_offense(
              send_node.loc.selector,
              message: format(MSG, wrong_column: wrong_column, correct_column: correct_column)
            )
          end
        end

        private

        def attr_encrypted_wrong_column(node)
          table_ref = node.children[0]
          column_name = node.children[2]

          if new_column_in_create_table_block?(table_ref, column_name)
            column_name.value if attr_encrypted_column?(column_name.value)
          elsif ADD_COLUMN_METHODS.include?(node.children[1])
            column_name =
              if node.children[3].type == :const
                const_assign = nil
                node.ancestors.each do |ancestor|
                  const_assign = find_constant(ancestor, node.children[3].short_name)
                  break const_assign if const_assign
                end
                const_assign.expression.value
              else
                node.children[3].value
              end

            column_name if table_ref.nil? && attr_encrypted_column?(column_name)
          end
        end

        def find_constant(node, name)
          return node.expression.value if node.type == :casgn && node.name == name

          node.children.find do |child|
            next unless child.is_a?(RuboCop::AST::Node)

            find_constant(child, name)
          end
        end

        def new_column_in_create_table_block?(table_ref, column_name)
          table_ref&.type == :lvar && %i[sym string].include?(column_name&.type)
        end

        def attr_encrypted_column?(column_name)
          column_name.start_with?('encrypted_')
        end
      end
    end
  end
end
