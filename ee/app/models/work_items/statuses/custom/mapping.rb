# frozen_string_literal: true

module WorkItems
  module Statuses
    module Custom
      class Mapping < ApplicationRecord
        self.table_name = 'work_item_custom_status_mappings'

        belongs_to :namespace
        belongs_to :old_status, class_name: 'WorkItems::Statuses::Custom::Status'
        belongs_to :new_status, class_name: 'WorkItems::Statuses::Custom::Status'
        belongs_to :work_item_type, class_name: 'WorkItems::Type'

        validates :old_status, :new_status, :work_item_type, :namespace, presence: true

        validates :old_status_id, uniqueness: {
          scope: [:namespace_id, :new_status_id, :work_item_type_id],
          message: 'mapping already exists for this combination'
        }

        validate :statuses_in_same_namespace
        validate :no_self_mapping
        validate :no_chained_mappings
        validate :valid_date_range

        scope :in_namespace, ->(namespace) { where(namespace: namespace) }

        private

        def statuses_in_same_namespace
          return unless namespace && old_status && new_status
          return if old_status.namespace == namespace && new_status.namespace == namespace

          errors.add(:base, 'statuses must belong to the same namespace as the mapping')
        end

        def no_self_mapping
          return unless old_status_id && new_status_id
          return unless old_status_id == new_status_id

          errors.add(:new_status, 'cannot be the same as old status')
        end

        def no_chained_mappings
          return unless old_status_id && new_status_id

          errors.add(:new_status, 'is already mapped to another status') if mapping_exists_from_new_status?
          errors.add(:old_status, 'is already the target of another mapping') if mapping_exists_to_old_status?
        end

        def mapping_exists_from_new_status?
          self.class.exists?(
            old_status_id: new_status_id,
            namespace_id: namespace_id,
            work_item_type_id: work_item_type_id
          )
        end

        def mapping_exists_to_old_status?
          self.class.exists?(
            new_status_id: old_status_id,
            namespace_id: namespace_id,
            work_item_type_id: work_item_type_id
          )
        end

        def valid_date_range
          return unless valid_from && valid_until
          return unless valid_from >= valid_until

          errors.add(:valid_until, 'must be after valid_from date')
        end
      end
    end
  end
end
