# frozen_string_literal: true

module Security
  module ScanProfiles
    class ProjectAttachService
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

        inserted_ids = insert_under_limit
        handle_errors(inserted_ids)

        { errors: errors }
      rescue StandardError => e
        error_result(e.message)
      end

      private

      attr_reader :profile, :projects, :errors

      def valid_projects?
        errors << 'At least one project must be provided' if projects.empty?
        errors << "Cannot attach profile to more than #{MAX_PROJECTS} items at once." if projects.size > MAX_PROJECTS
        errors.empty?
      end

      def insert_under_limit
        sql = <<~SQL
          INSERT INTO security_scan_profiles_projects (project_id, security_scan_profile_id, created_at, updated_at)
          SELECT candidate_project_id, :profile_id, NOW(), NOW()
          FROM UNNEST(ARRAY[:project_ids]) AS candidate_project_id
          WHERE (
            SELECT COUNT(*) FROM security_scan_profiles_projects
            WHERE project_id = candidate_project_id
          ) < :max_limit
          ON CONFLICT (project_id, security_scan_profile_id) DO NOTHING
          RETURNING project_id;
        SQL

        sanitized_sql = ActiveRecord::Base.sanitize_sql_array([sql, {
          project_ids: projects.map(&:id),
          profile_id: profile.id,
          max_limit: Security::ScanProfileProject::MAX_PROFILES_PER_PROJECT
        }])

        # rubocop:disable Database/AvoidUsingPluckWithoutLimit: -- False positive. This is not a relation.
        Security::ScanProfileProject.connection.execute(sanitized_sql)
          .pluck('project_id') # rubocop:disable CodeReuse/ActiveRecord -- reading query result
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit:
      end

      def handle_errors(inserted_ids)
        requested_ids = projects.map(&:id)
        return if inserted_ids.size == requested_ids.size

        potential_error_ids = requested_ids - inserted_ids
        already_attached_ids = Security::ScanProfileProject
          .by_project_id(potential_error_ids)
          .for_scan_profile(profile.id)
          .limit(potential_error_ids.size)
          .pluck(:project_id) # rubocop:disable CodeReuse/ActiveRecord -- specific use case

        (potential_error_ids - already_attached_ids).each do |id|
          errors << "Project #{id} has reached the maximum limit of scan profiles."
        end
      end

      def error_result(message)
        {
          errors: [message]
        }
      end
    end
  end
end
