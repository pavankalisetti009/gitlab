# frozen_string_literal: true

module Geo
  class JobArtifactReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::Ci::JobArtifact
    end

    # @return [String] human-readable title.
    def self.replicable_title
      s_('Geo|CI Job Artifact')
    end

    # @return [String] pluralized human-readable title.
    def self.replicable_title_plural
      s_('Geo|CI Job Artifacts')
    end

    override :checksummed_count
    def self.checksummed_count
      return unless verification_enabled?

      batch_count(model.verification_state_table_class.with_verification_state(:verification_succeeded))
    end

    override :checksum_failed_count
    def self.checksum_failed_count
      return unless verification_enabled?

      batch_count(model.verification_state_table_class.with_verification_state(:verification_failed))
    end

    override :checksum_total_count
    def self.checksum_total_count
      return unless verification_enabled?

      batch_count(model.verification_state_table_class.all)
    end

    def carrierwave_uploader
      model_record.file
    end
  end
end
