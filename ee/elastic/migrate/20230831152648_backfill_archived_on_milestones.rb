# frozen_string_literal: true

class BackfillArchivedOnMilestones < Elastic::Migration
  include Elastic::MigrationBackfillHelper

  batched!
  batch_size 9_000
  throttle_delay 10.seconds

  DOCUMENT_TYPE = Milestone

  private

  def field_name
    'archived'
  end
end

BackfillArchivedOnMilestones.prepend ::Elastic::MigrationObsolete
