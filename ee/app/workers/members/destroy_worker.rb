# frozen_string_literal: true

module Members
  class DestroyWorker
    include ApplicationWorker

    feature_category :user_management
    data_consistency :delayed
    deduplicate :until_executed
    idempotent!

    def perform(member_id, user_id, skip_subresources = false)
      user = User.find_by_id(user_id)
      member = Member.find_by_id(member_id)

      return unless user && member

      ::Members::DestroyService.new(user).execute(member, skip_subresources: skip_subresources)
    end
  end
end
