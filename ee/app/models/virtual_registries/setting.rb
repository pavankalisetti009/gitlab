# frozen_string_literal: true

module VirtualRegistries
  class Setting < ApplicationRecord
    include SafelyChangeColumnDefault

    columns_changing_default :enabled

    belongs_to :group

    validates :group, top_level_group: true, presence: true
    validates :enabled, inclusion: { in: [true, false] }

    scope :for_group, ->(group) { where(group: group) }
    scope :enabled, -> { where(enabled: true) }
  end
end
