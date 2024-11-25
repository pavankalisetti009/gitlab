# frozen_string_literal: true

module Gitlab
  module CodeOwners
    class RolesLoader
      def initialize(project, extractor)
        @project = project
        @extractor = extractor
      end

      def load_to(entries)
        roles = @extractor.roles
        entries.each do |entry|
          entry.add_matching_roles_from(roles)
        end
      end
    end
  end
end
