# frozen_string_literal: true

module GitlabSubscriptions
  class SeatAssignment < ApplicationRecord
    belongs_to :namespace, optional: false
    belongs_to :user, optional: false

    validates :namespace_id, uniqueness: { scope: :user_id }
  end
end
