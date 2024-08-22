# frozen_string_literal: true

module Security
  class GroupAllowlistEntry < Gitlab::Database::SecApplicationRecord
    belongs_to :group

    enum scanner: { secret_push_protection: 0 }
    enum type: { path: 0, pattern: 1, raw_value: 2 }

    validates :scanner, :type, :value, presence: true
    validates :active, inclusion: { in: [true, false] }
  end
end
