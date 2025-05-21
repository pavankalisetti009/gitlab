# frozen_string_literal: true

module EE
  module Types
    module Namespaces
      module UserLevelPermissions
        module GroupNamespaceUserLevelPermissionsType
          def can_bulk_edit_epics
            can?(current_user, :bulk_admin_epic, group)
          end

          def can_create_epic
            can?(current_user, :create_epic, group)
          end
        end
      end
    end
  end
end
