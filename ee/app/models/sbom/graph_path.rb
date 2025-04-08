# frozen_string_literal: true

module Sbom
  class GraphPath < Gitlab::Database::SecApplicationRecord
    belongs_to :ancestor, class_name: 'Sbom::Occurrence', optional: false
    belongs_to :descendant, class_name: 'Sbom::Occurrence', optional: false
    belongs_to :project, class_name: 'Project'

    validates :path_length, presence: true
  end
end
