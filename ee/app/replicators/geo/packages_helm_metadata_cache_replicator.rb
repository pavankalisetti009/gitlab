# frozen_string_literal: true

module Geo
  class PackagesHelmMetadataCacheReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::Packages::Helm::MetadataCache
    end

    # @return [String] human-readable title.
    def self.replicable_title
      s_('Geo|Helm Metadata Cache')
    end

    # @return [String] pluralized human-readable title.
    def self.replicable_title_plural
      s_('Geo|Helm Metadata Caches')
    end

    def carrierwave_uploader
      model_record.file
    end
  end
end
