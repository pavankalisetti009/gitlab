# frozen_string_literal: true

module Ci
  class RunnerControllerRunnerLevelScoping < Ci::ApplicationRecord
    self.table_name = :ci_runner_controller_runner_level_scopings
    self.primary_key = :id

    query_constraints :runner_id, :runner_type

    before_validation :set_runner_type, on: :create, if: -> { runner_type.nil? && runner }

    enum :runner_type, Ci::Runner.runner_types

    belongs_to :runner_controller,
      class_name: 'Ci::RunnerController',
      inverse_of: :runner_level_scopings,
      optional: false

    belongs_to :runner,
      class_name: 'Ci::Runner',
      inverse_of: :runner_controller_runner_level_scopings,
      optional: false

    validates :runner_type, presence: true
    validates :runner_controller_id, uniqueness: { scope: [:runner_id, :runner_type] }

    private

    def set_runner_type
      self.runner_type = runner.runner_type
    end
  end
end
