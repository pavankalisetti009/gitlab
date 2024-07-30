# frozen_string_literal: true

# Gitlab::Access module
#
# Define allowed roles that can be used
# in GitLab code to determine authorization level
#
module EE
  module Gitlab
    module Access
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      MINIMAL_ACCESS_HASH = { "Minimal Access" => ::Gitlab::Access::MINIMAL_ACCESS }.freeze

      class_methods do
        extend ::Gitlab::Utils::Override

        def vulnerability_access_levels
          @vulnerability_access_levels ||= sym_options_with_owner.values_at(:developer, :maintainer, :owner).freeze
        end

        def options_with_minimal_access
          options_with_owner.merge(MINIMAL_ACCESS_HASH)
        end

        def values_with_minimal_access
          options_with_minimal_access.values
        end

        override :human_access
        def human_access(access, member_role = nil)
          member_role&.name || options_with_minimal_access.key(access)
        end
      end

      override :human_access
      def human_access
        ::Gitlab::Access.human_access(access_field, member_role)
      end

      override :human_access_labeled
      def human_access_labeled
        return super unless member_role

        "#{s_('Custom role')}: #{member_role.name}"
      end
    end
  end
end
