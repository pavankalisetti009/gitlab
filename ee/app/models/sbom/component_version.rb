# frozen_string_literal: true

module Sbom
  class ComponentVersion < ApplicationRecord
    belongs_to :component, optional: false

    validates :version, presence: true, length: { maximum: 255 }

    scope :by_component_id_and_version, ->(component_id, version) do
      where(component_id: component_id, version: version)
    end
  end
end
