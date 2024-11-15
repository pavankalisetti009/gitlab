# frozen_string_literal: true

module ComplianceManagement
  class PiplUser < ApplicationRecord
    NOTICE_PERIOD = 60.days

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

    def pipl_access_end_date
      return if initial_email_sent_at.blank?

      initial_email_sent_at.to_date + NOTICE_PERIOD
    end

    def reset_notification!
      update(initial_email_sent_at: nil)
    end

    def notification_sent!
      update!(initial_email_sent_at: Time.current)
    end
  end
end
