# frozen_string_literal: true

class ReindexWorkItemsToUpdateIntegerWithLongType < Elastic::Migration
  include ::Search::Elastic::MigrationReindexTaskHelper

  def targets
    %w[WorkItem]
  end
end
