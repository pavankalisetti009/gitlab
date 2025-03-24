# frozen_string_literal: true

module Gitlab
  module CodeOwners
    module OwnerValidation
      class BaseFilter
        def initialize(project, users: nil, groups: nil, emails: nil, names: nil)
          @project = project
          @input_users = users
          @input_groups = groups
          @input_names = names
          @input_emails = emails
        end

        # Define a constant named ERROR_MESSAGE in the filter class which
        # corresponds to one of the expected messages for
        # Gitlab::CodeOwners::Error.
        def error_message
          self.class::ERROR_MESSAGE
        end

        attr_accessor :valid_usernames, :valid_group_names, :valid_emails,
          :invalid_names, :invalid_emails, :output_users, :output_groups

        private

        attr_reader :project, :input_users, :input_groups, :input_names, :input_emails
      end
    end
  end
end
