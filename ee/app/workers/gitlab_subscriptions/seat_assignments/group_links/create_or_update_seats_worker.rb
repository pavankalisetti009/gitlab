# frozen_string_literal: true

module GitlabSubscriptions
  module SeatAssignments
    module GroupLinks
      class CreateOrUpdateSeatsWorker
        include ApplicationWorker

        feature_category :seat_cost_management
        data_consistency :delayed

        idempotent!

        def perform(link_id)
          link = GroupGroupLink.find_by_id(link_id)

          return unless link

          invited_group = link.shared_with_group
          root_namespace = link.shared_group.root_ancestor

          return if root_namespace.id == invited_group.root_ancestor.id

          invited_group.users.each_batch do |batch|
            batch.each do |user|
              seat = ::GitlabSubscriptions::SeatAssignment.find_by_namespace_and_user(root_namespace, user)

              next if seat

              SeatAssignment.create!(
                namespace: root_namespace,
                user: user,
                organization_id: root_namespace.organization_id
              )
            end
          end
        end
      end
    end
  end
end
