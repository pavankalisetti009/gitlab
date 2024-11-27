# frozen_string_literal: true

Settings['cron_jobs'] ||= {}
Settings.cron_jobs['send_recurring_notifications_worker'] ||= {}
Settings.cron_jobs['send_recurring_notifications_worker']['cron'] ||= '0 7 * * *'
Settings.cron_jobs['send_recurring_notifications_worker']['job_class'] =
  'ComplianceManagement::Pipl::SendRecurringNotificationsWorker'
