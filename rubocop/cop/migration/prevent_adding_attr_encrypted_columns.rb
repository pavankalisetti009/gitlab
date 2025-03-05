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
          return unless should_check_node?(node)

          check_encrypted_columns(node)
        end

        private

        def should_check_node?(node)
          in_migration?(node) && !reverting?(node)
        end

        def check_encrypted_columns(node)
          node.each_descendant(:send) do |send_node|
            process_encrypted_column(send_node)
          end
        end

        def process_encrypted_column(send_node)
          wrong_column = attr_encrypted_wrong_column(send_node)
          return unless wrong_column

          correct_column = derive_correct_column_name(wrong_column)
          register_offense(send_node, wrong_column, correct_column)
        end

        def derive_correct_column_name(wrong_column)
          wrong_column.to_s.delete_prefix('encrypted_').delete_suffix('_iv')
        end

        def register_offense(send_node, wrong_column, correct_column)
          add_offense(
            send_node.loc.selector,
            message: format(MSG, wrong_column: wrong_column, correct_column: correct_column)
          )
        end

        def attr_encrypted_wrong_column(node)
          table_ref = node.children[0]
          column_name = node.children[2]

          if new_column_in_create_table_block?(table_ref, column_name)
            return handle_create_table_column(table_ref, column_name)
          end

          handle_add_column(node, table_ref) if add_column_method?(node)
        end

        def new_column_in_create_table_block?(table_ref, column_name)
          table_ref&.type == :lvar && %i[sym string].include?(column_name&.type)
        end

        def handle_create_table_column(table_ref, column_name)
          return unless new_column_in_create_table_block?(table_ref, column_name)

          column_value = column_name.value
          column_name.value if attr_encrypted_column?(column_value)
        end

        def attr_encrypted_column?(column_name)
          column_name.start_with?('encrypted_')
        end

        def add_column_method?(node)
          ADD_COLUMN_METHODS.include?(node.children[1])
        end

        def handle_add_column(node, table_ref)
          return unless table_ref.nil?

          column_name = extract_column_name(node)
          column_name if attr_encrypted_column?(column_name)
        end

        def extract_column_name(node)
          column_def = node.children[3]

          if column_def.type == :const
            resolve_constant_value(node, column_def.short_name)
          else
            column_def.value
          end
        end

        def resolve_constant_value(node, const_name)
          node.ancestors.each do |ancestor|
            constant = find_constant(ancestor, const_name)
            return constant.expression.value if constant
          end
        end

        def find_constant(node, name)
          return node.expression.value if constant_assignment_matches?(node, name)

          node.children.find do |child|
            next unless valid_node?(child)

            find_constant(child, name)
          end
        end

        def constant_assignment_matches?(node, name)
          node.type == :casgn && node.name == name
        end

        def valid_node?(node)
          node.is_a?(RuboCop::AST::Node)
        end
      end
    end
  end
end
