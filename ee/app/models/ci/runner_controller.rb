# frozen_string_literal: true

module Ci
  class RunnerController < Ci::ApplicationRecord
    ignore_column :enabled, remove_with: '18.11', remove_after: '2026-03-14'

    validates :description, length: { maximum: 1024 }

    enum :state, {
      disabled: 0,
      enabled: 1,
      dry_run: 2
    }

    has_many :tokens,
      class_name: 'Ci::RunnerControllerToken',
      inverse_of: :runner_controller

    has_one :instance_level_scoping,
      class_name: 'Ci::RunnerControllerInstanceLevelScoping',
      inverse_of: :runner_controller

    has_many :runner_level_scopings,
      class_name: 'Ci::RunnerControllerRunnerLevelScoping',
      inverse_of: :runner_controller

    # Scope for controllers that are active (enabled or dry_run)
    scope :active, -> { where(state: [:enabled, :dry_run]) }

    # Scope for controllers with instance-level scoping
    scope :with_instance_scope, -> { joins(:instance_level_scoping) }
  end
end
