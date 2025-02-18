# frozen_string_literal: true

module Ci
  module Minutes
    # Track compute usage at the runner level.
    # For gitlab dedicated hosted runners only
    class GitlabHostedRunnerMonthlyUsage < Ci::ApplicationRecord
      include Ci::NamespacedModelName

      belongs_to :project, inverse_of: :hosted_runner_monthly_usages
      belongs_to :root_namespace, class_name: 'Namespace', inverse_of: :hosted_runner_monthly_usages
      belongs_to :runner, class_name: 'Ci::Runner', inverse_of: :hosted_runner_monthly_usages

      validates :runner, presence: true, on: :create
      validates :project, presence: true, on: :create
      validates :root_namespace, presence: true, on: :create

      validates :billing_month, presence: true
      validates :compute_minutes_used,
        numericality: { greater_than_or_equal_to: 0, allow_nil: false, only_float: true },
        presence: true
      validates :runner_duration_seconds, numericality: {
        greater_than_or_equal_to: 0,
        allow_nil: false,
        only_integer: true
      }
      validate :validate_billing_month_format

      scope :instance_aggregate, ->(billing_month, year) do
        select("TO_CHAR(billing_month, 'FMMonth YYYY') AS billing_month_formatted",
          'billing_month AS billing_month',
          'TO_CHAR(DATE_TRUNC(\'month\', billing_month), \'YYYY-MM-DD\') AS billing_month_iso8601',
          'SUM(compute_minutes_used) AS compute_minutes',
          'SUM(runner_duration_seconds) AS duration_seconds',
          'NULL as root_namespace_id')
        .where(billing_month: billing_month_range(billing_month, year))
        .group(:billing_month)
        .order(billing_month: :desc)
      end

      scope :per_root_namespace, ->(billing_month, year) do
        where(billing_month: billing_month_range(billing_month, year))
          .group(:billing_month, :root_namespace_id)
          .select("TO_CHAR(billing_month, 'FMMonth YYYY') AS billing_month_formatted",
            'billing_month AS billing_month',
            'TO_CHAR(DATE_TRUNC(\'month\', billing_month), \'YYYY-MM-DD\') AS billing_month_iso8601',
            'root_namespace_id',
            'SUM(compute_minutes_used) AS compute_minutes',
            'SUM(runner_duration_seconds) AS duration_seconds')
          .order(billing_month: :desc, root_namespace_id: :asc)
      end

      private

      def self.billing_month_range(billing_month, year)
        if billing_month.present?
          start_date = billing_month
          end_date = start_date.end_of_month
        else
          year ||= Time.current.year
          start_date = Date.new(year, 1, 1)
          end_date = Date.new(year, 12, 31)
        end

        start_date..end_date
      end

      def validate_billing_month_format
        return if billing_month.blank?

        return if billing_month == billing_month.beginning_of_month

        errors.add(:billing_month, 'must be the first day of the month')
      end
    end
  end
end
