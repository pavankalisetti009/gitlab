# frozen_string_literal: true

module PackageMetadata
  module DataObjects
    class CveEnrichment
      def self.create(data, _purl_type)
        new(**data.transform_keys(&:to_sym))
      end

      attr_accessor :cve_id, :epss_score

      def initialize(cve_id:, epss_score:)
        @cve_id = cve_id
        @epss_score = epss_score
      end

      def ==(other)
        cve_id == other.cve_id &&
          epss_score == other.epss_score
      end
    end
  end
end
