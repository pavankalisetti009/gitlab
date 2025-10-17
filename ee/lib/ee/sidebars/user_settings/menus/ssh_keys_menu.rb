# frozen_string_literal: true

module EE
  module Sidebars # rubocop:disable Gitlab/BoundedContexts -- prepended class is not inside a bounded context namespace
    module UserSettings
      module Menus
        module SshKeysMenu
          extend ::Gitlab::Utils::Override

          override :render?
          def render?
            return false if context.current_user&.enterprise_group&.disable_ssh_keys?

            super
          end
        end
      end
    end
  end
end
