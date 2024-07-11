# frozen_string_literal: true

module Sbom
  class SourcePackage < ::Gitlab::Database::SecApplicationRecord
    enum purl_type: ::Enums::Sbom.purl_types

    scope :by_purl_type_and_name, ->(purl_type, name) do
      where(name: name, purl_type: purl_type)
    end
  end
end
