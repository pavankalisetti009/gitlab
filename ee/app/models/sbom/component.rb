# frozen_string_literal: true

module Sbom
  class Component < ::Gitlab::Database::SecApplicationRecord
    has_many :occurrences, inverse_of: :component

    enum component_type: ::Enums::Sbom.component_types
    enum purl_type: ::Enums::Sbom.purl_types

    belongs_to :organization, class_name: 'Organizations::Organization'

    validates :component_type, presence: true
    validates :name, presence: true, length: { maximum: 255 }

    scope :libraries, -> { where(component_type: :library) }
    scope :by_purl_type_and_name, ->(purl_type, name) do
      where(name: name, purl_type: purl_type)
    end

    scope :by_unique_attributes, ->(name, purl_type, component_type, organization_id) do
      where(name: name, purl_type: purl_type, component_type: component_type, organization_id: organization_id)
    end

    scope :by_name, ->(name) do
      where(Sbom::Component.arel_table[:name].matches("%#{name}%"))
    end
  end
end
