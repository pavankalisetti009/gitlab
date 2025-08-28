# frozen_string_literal: true

module VirtualRegistries
  class RegistryUpstream < ApplicationRecord
    self.abstract_class = true

    belongs_to :group

    validates :upstream_id, uniqueness: { scope: :registry_id }, if: :upstream_id?
    validates :registry_id, uniqueness: { scope: [:position] }

    validates :group, top_level_group: true, presence: true
    validates :position,
      numericality: {
        only_integer: true,
        greater_than_or_equal_to: 1,
        less_than_or_equal_to: ->(record) { record.class::MAX_UPSTREAMS_COUNT }
      },
      presence: true

    before_validation :set_group, :set_position, on: :create

    private

    def set_group
      self.group ||= (registry || upstream).group
    end

    def set_position
      self.position = self.class.where(registry:, group:).maximum(:position).to_i + 1
    end
  end
end
