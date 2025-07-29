# frozen_string_literal: true

module EE
  module Types
    module PermissionTypes
      module Project
        extend ActiveSupport::Concern

        prepended do
          abilities :read_path_locks, :create_path_lock, :admin_path_locks, :generate_description,
            :admin_work_item_lifecycle
        end
      end
    end
  end
end
