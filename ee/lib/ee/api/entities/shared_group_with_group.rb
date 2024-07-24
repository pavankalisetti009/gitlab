# frozen_string_literal: true

module EE
  module API
    module Entities
      module SharedGroupWithGroup
        extend ActiveSupport::Concern

        prepended do
          expose :member_role_id, documentation: { type: 'integer', example: 12 }, if: ->(group_link, options) do
            group_link.shared_group.custom_roles_enabled? &&
              ::Feature.enabled?(:assign_custom_roles_to_group_links, options[:current_user])
          end
        end
      end
    end
  end
end
