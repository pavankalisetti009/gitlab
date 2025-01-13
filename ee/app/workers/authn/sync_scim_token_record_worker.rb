# frozen_string_literal: true

module Authn
  class SyncScimTokenRecordWorker
    include ApplicationWorker

    data_consistency :sticky
    feature_category :system_access

    idempotent!

    def perform(args)
      scim_token = ScimOauthAccessToken.find_by(id: args['group_scim_token_id']) # rubocop:disable CodeReuse/ActiveRecord -- temporary worker for the purpose of syncing
      return if scim_token.blank? || scim_token.group.blank?

      group_scim_token = GroupScimAuthAccessToken.find_or_initialize_by(temp_source_id: scim_token.id) # rubocop:disable CodeReuse/ActiveRecord -- temporary worker for the purpose of syncing

      return unless group_scim_token.new_record? || scim_token.updated_at > group_scim_token.updated_at

      group_scim_token.assign_attributes(
        temp_source_id: scim_token.id,
        token_encrypted: scim_token.token_encrypted,
        group: scim_token.group
      )
      group_scim_token.save!
    end
  end
end
