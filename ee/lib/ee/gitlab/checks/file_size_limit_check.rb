# frozen_string_literal: true

module EE
  module Gitlab
    module Checks
      module FileSizeLimitCheck
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        private

        override :file_size_limit
        def file_size_limit
          if ::Feature.enabled?(:push_rule_file_size_limit, project)
            global_limit = super
            return global_limit if push_rule.nil?

            push_rule_limit = push_rule.max_file_size
            return push_rule_limit if global_limit.nil?
            return global_limit if push_rule_limit == 0

            [push_rule_limit, global_limit].min
          else
            super
          end
        end
      end
    end
  end
end
