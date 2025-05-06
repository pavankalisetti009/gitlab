# frozen_string_literal: true

module Geo
  class LfsObjectReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def carrierwave_uploader
      model_record.file
    end

    # @return [String] human-readable title.
    def self.replicable_title
      s_('Geo|Lfs Object')
    end

    # @return [String] pluralized human-readable title.
    def self.replicable_title_plural
      s_('Geo|Lfs Objects')
    end

    def self.model
      ::LfsObject
    end
  end
end
