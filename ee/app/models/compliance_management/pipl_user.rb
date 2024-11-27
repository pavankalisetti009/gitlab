# frozen_string_literal: true

module ComplianceManagement
  class PiplUser < ApplicationRecord
    include EachBatch

    LEVEL_1_NOTIFICATION_TIME = 30.days
    LEVEL_2_NOTIFICATION_TIME = 53.days
    LEVEL_3_NOTIFICATION_TIME = 59.days

    NOTICE_PERIOD = 60.days

    belongs_to :user, optional: false

    scope :days_from_initial_pipl_email, ->(*days) do
      sent_mail_ranges = days.map do |day_count|
        day_count.ago.beginning_of_day..day_count.ago.end_of_day
      end

      includes(:user).where(initial_email_sent_at: sent_mail_ranges)
    end

    scope :with_due_notifications, -> do
      days_from_initial_pipl_email(*[LEVEL_1_NOTIFICATION_TIME, LEVEL_2_NOTIFICATION_TIME, LEVEL_3_NOTIFICATION_TIME])
    end

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

    def remaining_pipl_access_days
      (pipl_access_end_date - Date.current).to_i
    end
  end
end
