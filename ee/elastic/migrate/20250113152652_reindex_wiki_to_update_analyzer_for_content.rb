# frozen_string_literal: true

class ReindexWikiToUpdateAnalyzerForContent < Elastic::Migration
  include Search::Elastic::MigrationReindexBasedOnSchemaVersion

  batched!
  batch_size 9_000
  throttle_delay 1.minute

  DOCUMENT_TYPE = Wiki
  NEW_SCHEMA_VERSION = 2504
end
