# frozen_string_literal: true

module Security
  module ScanProfiles
    class ProjectDetachService
      MAX_PROJECTS = 500

      def self.execute(...)
        new(...).execute
      end

      def initialize(profile:, projects: [])
        @profile = profile
        @projects = projects
        @errors = []
      end

      def execute
        return { errors: errors } unless valid_projects?

        delete_profile_projects

        { errors: errors }
      rescue StandardError => e
        error_result(e.message)
      end

      private

      attr_reader :profile, :projects, :errors

      def valid_projects?
        errors << 'At least one project must be provided' if projects.empty?
        errors << "Cannot detach profile from more than #{MAX_PROJECTS} items at once." if projects.size > MAX_PROJECTS
        errors.empty?
      end

      def delete_profile_projects
        Security::ScanProfileProject
          .by_project_id(projects.map(&:id))
          .for_scan_profile(profile.id)
          .delete_all
      end

      def error_result(message)
        {
          errors: [message]
        }
      end
    end
  end
end
