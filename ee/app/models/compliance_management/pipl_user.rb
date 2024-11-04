# frozen_string_literal: true

module ComplianceManagement
  class PiplUser < ApplicationRecord
    belongs_to :user, optional: false

    validates :last_access_from_pipl_country_at, presence: true

    def self.for_user(user)
      find_by(user: user)
    end

    def self.untrack_access!(user)
      where(user: user).delete_all if user.is_a?(User)
    end

    def self.track_access(user)
      upsert({ user_id: user.id, last_access_from_pipl_country_at: Time.current }, unique_by: :user_id)
    end

    def recently_tracked?
      last_access_from_pipl_country_at.after?(24.hours.ago)
    end
  end
end
