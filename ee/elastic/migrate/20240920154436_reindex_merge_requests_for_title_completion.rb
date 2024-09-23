# frozen_string_literal: true

class ReindexMergeRequestsForTitleCompletion < Elastic::Migration
  space_requirements!

  def migrate
    Elastic::ReindexingTask.create!(targets: %w[MergeRequest], options: { skip_pending_migrations_check: true })
  end

  def completed?
    true
  end

  def space_required_bytes
    3 * helper.index_size_bytes(index_name: MergeRequest.index_name)
  end
end
