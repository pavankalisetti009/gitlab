# frozen_string_literal: true

module Vulnerabilities
  class ProjectsGrade
    BATCH_SIZE = 500

    attr_reader :vulnerable, :grade, :project_ids, :include_subgroups

    # project_ids can contain IDs from projects that do not belong to vulnerable, they will be filtered out in `projects` method
    def initialize(vulnerable, letter_grade, project_ids = [], include_subgroups: false)
      @vulnerable = vulnerable
      @grade = letter_grade
      @project_ids = project_ids
      @include_subgroups = include_subgroups
    end

    delegate :count, to: :projects

    def projects
      return Project.none if project_ids.blank?

      projects = include_subgroups ? vulnerable.all_projects : vulnerable.projects
      projects = projects.non_archived
      projects.with_vulnerability_statistics.inc_routes.where(id: project_ids)
    end

    def self.grades_for(vulnerables, filter: nil, include_subgroups: false)
      if vulnerables.all? { |v| v.is_a?(Group) && Feature.enabled?(:remove_cross_join_from_vulnerabilities_projects_grade, v) }
        return grades_for_vulnerables_no_cross_join(vulnerables, filter: filter, include_subgroups: include_subgroups)
      end

      projects = vulnerables.map do |v|
        collection = include_subgroups ? v.all_projects : v.projects
        collection.non_archived
      end

      relation = ::Vulnerabilities::Statistic.for_project(projects.reduce(&:or))
      relation = relation.by_grade(filter) if filter
      relation = relation.allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/503387')

      relation.group(:letter_grade)
              .select(:letter_grade, 'array_agg(project_id) project_ids')
              .then do |statistics|
                vulnerables.index_with do |vulnerable|
                  statistics.map { |statistic| new(vulnerable, statistic.letter_grade, statistic.project_ids, include_subgroups: include_subgroups) }
                end
              end
    end

    def self.grades_for_vulnerables_no_cross_join(vulnerables, filter: nil, include_subgroups: false)
      statistics = {}

      vulnerables.each do |group|
        iterator = if include_subgroups
                     cursor = { current_id: group.id, depth: [group.id] }
                     Gitlab::Database::NamespaceEachBatch.new(namespace_class: Group, cursor: cursor)
                   else
                     Group.where(id: group.id)
                   end

        iterator.each_batch do |sub_group_ids|
          Project.in_namespace(sub_group_ids).non_archived.each_batch do |projects|
            project_ids = projects.pluck_primary_key
            relation = ::Vulnerabilities::Statistic.for_project(project_ids)
            relation = relation.by_grade(filter) if filter

            relation.group(:letter_grade)
            .select(:letter_grade, 'array_agg(project_id) project_ids')
            .each do |row|
              statistics[row.letter_grade] ||= []
              statistics[row.letter_grade].concat(row.project_ids)
            end
          end
        end
      end

      # Currently all vulnerables get the same grades, but this behavior should be changed
      # as part of https://gitlab.com/gitlab-org/gitlab/-/issues/507992.
      vulnerables.index_with do |vulnerable|
        statistics.map { |letter_grade, project_ids| new(vulnerable, letter_grade, project_ids, include_subgroups: include_subgroups) }
      end
    end
    private_class_method :grades_for_vulnerables_no_cross_join
  end
end
