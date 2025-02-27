# frozen_string_literal: true

class ReindexWorkItemsToBackfillNotes < Elastic::Migration
  include Search::Elastic::MigrationReindexBasedOnSchemaVersion
  extend ::Gitlab::Utils::Override

  skip_if -> { !::Gitlab::Saas.feature_available?(:advanced_search) }

  batched!
  batch_size 9_000
  throttle_delay 1.minute

  DOCUMENT_TYPE = WorkItem
  NEW_SCHEMA_VERSION = 25_09
  UPDATE_BATCH_SIZE = 100

  private

  override :index_name
  def index_name
    Search::Elastic::Types::WorkItem.index_name
  end
end
