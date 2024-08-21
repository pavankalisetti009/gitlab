# frozen_string_literal: true

module Security
  class ProjectAllowlistEntry < Gitlab::Database::SecApplicationRecord
    belongs_to :project

    enum scanner: { secret_push_protection: 0 }
    enum type: { path: 0, pattern: 1, raw_value: 2 }

    validates :scanner, :type, :value, :project, presence: true
    validates :active, inclusion: { in: [true, false] }
  end
end
