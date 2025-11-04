# frozen_string_literal: true

module VirtualRegistries
  class Setting < ApplicationRecord
    belongs_to :group

    validates :group, top_level_group: true, presence: true, uniqueness: true
    validates :enabled, inclusion: { in: [true, false] }

    scope :enabled, -> { where(enabled: true) }

    def self.find_for_group(group)
      find_or_initialize_by(group: group)
    end
  end
end
