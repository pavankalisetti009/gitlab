# frozen_string_literal: true

module Ai
  module ModelSelection
    module SelectionApplicable
      extend ActiveSupport::Concern

      def current_user
        raise NotImplementedError, "#current_user method must be implement in #{self.class.name}"
      end

      included do
        def get_default_duo_namespace
          current_user.user_preference.get_default_duo_namespace
        end
        strong_memoize_attr :get_default_duo_namespace

        def distinct_eligible_assignments
          current_user.user_preference.distinct_eligible_duo_add_on_assignments
        end
        strong_memoize_attr :distinct_eligible_assignments

        def user_assigned_duo_namespaces
          distinct_eligible_assignments.map(&:namespace)
        end
        strong_memoize_attr :user_assigned_duo_namespaces

        def default_duo_namespace_required?
          # we need to return the default namespace only when there is multiple seats assigned to the user.
          # Otherwise, we might have error in undesirable cases
          # e.g. when self-hosted feature setting are not correctly set
          return false if get_default_duo_namespace

          # if any of the assigned seat has a namespace with model switching enable
          # it is required for the user to have a default namespace to be selected.
          # This logic is in EE::UserPolicy#can_assign_default_duo_group?
          Ability.allowed?(current_user, :assign_default_duo_group, current_user)
        end
      end
    end
  end
end
