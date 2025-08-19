# frozen_string_literal: true

# rubocop:disable Scalability/IdempotentWorker -- Idempotent declaration in child
module GitlabSubscriptions
  module SeatAssignments
    module MemberTransfers
      class BaseCreateSeatsWorker
        BATCH_SIZE = 100

        def perform(source_id)
          source = find_source_by_id(source_id)
          return unless source

          create_missing_seat_assignments(source)
        end

        private

        def create_missing_seat_assignments(source)
          namespace_id = source.root_ancestor.id
          organization_id = source.root_ancestor.organization_id

          collect_user_ids(source).each_batch(of: BATCH_SIZE) do |users|
            seat_assignments = users.pluck_user_ids.map do |user_id|
              {
                namespace_id: namespace_id,
                user_id: user_id,
                organization_id: organization_id
              }
            end

            ::GitlabSubscriptions::SeatAssignment.insert_all(
              seat_assignments,
              unique_by: [:namespace_id, :user_id]
            )
          end
        end

        def collect_user_ids(_source)
          raise NotImplementedError
        end

        def find_source_by_id(_source_id)
          raise NotImplementedError
        end
      end
    end
  end
end
# rubocop:enable Scalability/IdempotentWorker
