# frozen_string_literal: true

module Sbom
  class ComponentVersion < Gitlab::Database::SecApplicationRecord
    belongs_to :component, optional: false
    has_many :occurrences, inverse_of: :component_version

    validates :version, presence: true, length: { maximum: 255 }
  end
end
