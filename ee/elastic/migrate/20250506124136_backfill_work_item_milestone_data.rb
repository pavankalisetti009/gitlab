# frozen_string_literal: true

class BackfillWorkItemMilestoneData < Elastic::Migration
  include ::Search::Elastic::MigrationBackfillHelper

  batched!
  throttle_delay 1.minute

  DOCUMENT_TYPE = WorkItem

  private

  def field_names
    %w[milestone_id milestone_title]
  end
end
