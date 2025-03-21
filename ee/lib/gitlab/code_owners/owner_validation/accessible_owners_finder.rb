# frozen_string_literal: true

module Gitlab
  module CodeOwners
    module OwnerValidation
      class AccessibleOwnersFinder < BaseFinder
        ERROR_MESSAGE = :inaccessible_owner

        def execute
          self.output_groups = GroupsLoader.new(project, names: input_names).groups
          self.valid_group_names = output_groups.map(&:full_path)

          remaining_names = input_names - valid_group_names
          self.output_users = UsersLoader.new(project, emails: input_emails, names: remaining_names).members

          self.invalid_names = remaining_names - output_users.map(&:username)
          self.invalid_emails = input_emails - output_users.flat_map(&:verified_emails)
          self.valid_usernames = input_names - invalid_names - valid_group_names
          self.valid_emails = input_emails - invalid_emails
        end
      end
    end
  end
end
