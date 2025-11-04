# frozen_string_literal: true

module EE
  module UserPreference
    extend ActiveSupport::Concern

    prepended do
      extend ::Gitlab::Utils::Override

      belongs_to :default_duo_add_on_assignment, class_name: 'GitlabSubscriptions::UserAddOnAssignment', optional: true
      belongs_to :duo_default_namespace, class_name: 'Namespace', optional: true

      validates :roadmap_epics_state, allow_nil: true, inclusion: {
        in: ::Epic.available_states.values, message: "%{value} is not a valid epic state id"
      }

      validates :epic_notes_filter, inclusion: { in: ::UserPreference::NOTES_FILTERS.values }, presence: true

      validate :check_seat_for_default_duo_assigment, if: :default_duo_add_on_assignment_id_changed?
      validate :validate_duo_default_namespace_id, if: :duo_default_namespace_id_changed?

      def duo_default_namespace_candidates
        if ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)
          duo_core_subquery = GitlabSubscriptions::AddOn.select(:id).where(name: :duo_core)
          duo_assignable_subquery =
            GitlabSubscriptions::AddOn
              .select(:id).where(name: ::GitlabSubscriptions::AddOn::SEAT_ASSIGNABLE_DUO_ADD_ONS)
          add_on_id_column = GitlabSubscriptions::AddOnPurchase.arel_table[:subscription_add_on_id]

          namespace_ids_subquery = GitlabSubscriptions::AddOnPurchase
            .for_duo_add_ons
            .active.for_user(user)
            .left_outer_joins(:assigned_users)
            .where(
              add_on_id_column.in(duo_core_subquery.arel).or(
                add_on_id_column.in(duo_assignable_subquery.arel)
                  .and(GitlabSubscriptions::UserAddOnAssignment.arel_table[:id].not_eq(nil))
              )
            )
            .distinct
            .select(:namespace_id)

          ::Namespace.where(id: namespace_ids_subquery)
        else
          ::Namespace.where(id: user.authorized_groups.top_level).or(::Namespace.where(id: user.namespace))
        end
      end

      validates :policy_advanced_editor, allow_nil: false, inclusion: { in: [true, false] }

      attribute :policy_advanced_editor, default: false

      scope :policy_advanced_editor, -> { where(policy_advanced_editor: true) }

      # EE:SaaS - namespace with seats for SAAS purpose only
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/557584
      def eligible_duo_add_on_assignments
        assignable_enum_value = ::GitlabSubscriptions::AddOn.names.values_at(
          *::GitlabSubscriptions::AddOn::SEAT_ASSIGNABLE_DUO_ADD_ONS
        )

        GitlabSubscriptions::UserAddOnAssignment
                                    .by_user(user)
                                    .with_namespaces
                                    .joins(add_on_purchase: :add_on)
                                    .where(add_on_purchase: { subscription_add_ons: { name: assignable_enum_value } })
                                    .where.not(add_on_purchase: { namespace_id: nil })
      end

      def distinct_eligible_duo_add_on_assignments
        distinct_query = 'DISTINCT ON (add_on_purchase.namespace_id) subscription_user_add_on_assignments.*'

        eligible_duo_add_on_assignments.select(distinct_query)
      end

      def check_seat_for_default_duo_assigment
        return if default_duo_add_on_assignment_id.nil?

        return if eligible_duo_add_on_assignments.exists?(id: default_duo_add_on_assignment_id)

        errors.add(:default_duo_add_on_assignment_id,
          "No Duo seat assignments with namespace found with ID #{default_duo_add_on_assignment_id}")
      end

      def no_eligible_duo_add_on_assignments?
        eligible_duo_add_on_assignments.none?
      end

      def get_default_duo_namespace
        return default_duo_add_on_assignment.namespace if default_duo_add_on_assignment.present?

        assignments = distinct_eligible_duo_add_on_assignments.limit(2).to_a

        return if assignments.size != 1

        assignments.first.add_on_purchase.namespace
      end

      override :duo_default_namespace
      def duo_default_namespace
        namespace = super

        if namespace
          duo_default_namespace_candidates.where(id: namespace.id).exists? ? namespace : nil
        else # Fallback to deprecated add-on assignment approach
          get_default_duo_namespace
        end
      end

      def duo_default_namespace_id=(namespace_id)
        # Prevent fallback to assignment id in future reads
        self.default_duo_add_on_assignment_id = nil if namespace_id.nil?
        super
      end

      private

      def validate_duo_default_namespace_id
        return unless duo_default_namespace_id

        return if duo_default_namespace_candidates.where(id: duo_default_namespace_id).exists?

        errors.add(:duo_default_namespace_id)
      end
    end
  end
end
