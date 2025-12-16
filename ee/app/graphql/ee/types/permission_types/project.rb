# frozen_string_literal: true

module EE
  module Types
    module PermissionTypes
      module Project
        extend ActiveSupport::Concern

        prepended do
          abilities :read_path_locks, :create_path_lock, :admin_path_locks, :generate_description,
            :admin_work_item_lifecycle

          ability_field :manage_ai_flow_triggers,
            experiment: { milestone: '18.3' }

          ability_field :read_ai_catalog_item,
            experiment: { milestone: '18.3' }

          ability_field :read_ai_catalog_item_consumer,
            experiment: { milestone: '18.3' }

          ability_field :admin_ai_catalog_item,
            experiment: { milestone: '18.3' }

          ability_field :admin_ai_catalog_item_consumer,
            experiment: { milestone: '18.3' }

          ability_field :read_runner_cloud_provisioning_info,
            experiment: { milestone: '18.8' }
        end
      end
    end
  end
end
