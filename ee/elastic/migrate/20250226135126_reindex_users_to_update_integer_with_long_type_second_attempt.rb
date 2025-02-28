# frozen_string_literal: true

class ReindexUsersToUpdateIntegerWithLongTypeSecondAttempt < Elastic::Migration
  def migrate
    Search::Elastic::ReindexingTask.create!(targets: %w[User], options: { skip_pending_migrations_check: true })
  end

  def completed?
    true
  end
end
