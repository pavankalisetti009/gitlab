# frozen_string_literal: true

# See https://docs.gitlab.com/ee/development/database/batched_background_migrations.html
# for more information on how to use batched background migrations

# Update below commented lines with appropriate values.

module Gitlab
  module BackgroundMigration
    class FixVulnerabilitiesTransitionedFromDismissedToResolved < BatchedMigrationJob
      # The earliest that records could have appeared on .com was when the feature flag was enabled
      # on 2024-12-05: https://gitlab.com/gitlab-org/gitlab/-/issues/505711
      #
      # In self-managed, it could have appeared beginning in the 17.7 release on 2024-12-19.
      FIRST_APPEARANCE_DATE = Date.new(2024, 12, 5)

      job_arguments :namespace_id, :instance
      operation_name :fix_vulnerabilities_transitioned_from_dismissed_to_resolved
      feature_category :vulnerability_management
      scope_to ->(vulnerability_reads) {
        relation = vulnerability_reads.where(state: [Vulnerability.states[:detected], Vulnerability.states[:resolved]])

        return relation if instance

        relation
          .where(vulnerability_reads.arel_table[:traversal_ids].gteq([namespace_id]))
          .where(vulnerability_reads.arel_table[:traversal_ids].lt([namespace_id.next]))
      }

      class Vulnerability < ::SecApplicationRecord
        self.table_name = 'vulnerabilities'

        has_many :state_transitions, -> { order(id: :desc) }, class_name: 'StateTransition'

        enum :state, {
          detected: 1,
          confirmed: 4,
          resolved: 3,
          dismissed: 2
        }

        scope :with_state_transitions_and_author, -> { preload(state_transitions: :author) }
        scope :transitioned_at_least_once, -> {
          where('EXISTS (SELECT 1 FROM vulnerability_state_transitions WHERE vulnerability_id = vulnerabilities.id)')
        }
      end

      class StateTransition < ::SecApplicationRecord
        self.table_name = 'vulnerability_state_transitions'

        belongs_to :author, class_name: 'User'

        def created_before_issue_first_appeared?
          created_at.before?(FIRST_APPEARANCE_DATE)
        end

        def transitioned_from_dismissed_to_resolved?
          from_state == 2 && to_state == 3
        end
      end

      class User < ApplicationRecord
        self.table_name = 'users'

        def security_policy_bot?
          user_type == 10
        end
      end

      def perform
        each_sub_batch do |vulnerability_reads|
          ids = affected_vulnerability_ids(vulnerability_reads)

          next if ids.blank?

          Vulnerability.id_in(ids).update_all(state: :dismissed)
        end
      end

      def affected_vulnerability_ids(vulnerability_reads)
        Vulnerability
          .id_in(vulnerability_reads.pluck(:vulnerability_id))
          .transitioned_at_least_once
          .with_state_transitions_and_author
          .filter_map do |vulnerability|
            next unless affected?(vulnerability)

            vulnerability.id
          end
      end

      def affected?(vulnerability)
        vulnerability.state_transitions.each do |state_transition|
          return false if state_transition.created_before_issue_first_appeared?
          # If the state has been transitioned by someone besides the security policy bot then we should
          # respect their decision. When a vulnerability is redetected by a scanner, the transition has no author.
          return false if state_transition.author.present? && !state_transition.author.security_policy_bot?
          return true if state_transition.transitioned_from_dismissed_to_resolved?
        end

        false
      end
    end
  end
end
