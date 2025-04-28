# frozen_string_literal: true

module Sbom
  class ComponentVersion < ::SecApplicationRecord
    include SafelyChangeColumnDefault

    columns_changing_default :organization_id

    belongs_to :component, optional: false
    has_many :occurrences, inverse_of: :component_version
    belongs_to :organization, class_name: 'Organizations::Organization'

    validates :version, presence: true, length: { maximum: 255 }

    scope :by_component_id_and_version, ->(component_id, version) do
      where(component_id: component_id, version: version)
    end

    def self.by_project_and_component(project_id, component_id)
      joins(:occurrences)
        .where(sbom_occurrences: { project_id: project_id, component_id: component_id }).distinct.order(version: :asc)
    end
  end
end
