# frozen_string_literal: true

class BackfillArchivedOnNotes < Elastic::Migration
  include Elastic::MigrationBackfillHelper

  batched!
  batch_size 9_000
  throttle_delay 10.seconds

  DOCUMENT_TYPE = Note

  private

  def field_name
    'archived'
  end
end

BackfillArchivedOnNotes.prepend ::Elastic::MigrationObsolete
