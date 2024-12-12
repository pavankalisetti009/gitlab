# frozen_string_literal: true

module Projects
  module CustomBranchRule
    extend ActiveSupport::Concern

    included do
      include GlobalID::Identification
      extend Forwardable

      attr_reader :project

      def_delegators(:project, :id)
    end

    class_methods do
      def find(id)
        project = Project.find(id)

        new(project)
      rescue ActiveRecord::RecordNotFound
        raise ActiveRecord::RecordNotFound, "Couldn't find #{name} with 'id'=#{id}"
      end
    end

    def initialize(project)
      @project = project
    end

    def any_rules?
      approval_project_rules.present? || external_status_checks.present?
    end
    alias_method :persisted?, :any_rules?

    def name
      raise NotImplementedError
    end

    def matching_branches_count
      raise NotImplementedError
    end

    def approval_project_rules
      raise NotImplementedError
    end

    def external_status_checks
      raise NotImplementedError
    end

    def default_branch?
      false
    end

    def protected?
      false
    end

    def branch_protection
      nil
    end

    def group
      nil
    end

    def squash_option
      nil
    end

    def created_at
      [
        *external_status_checks.map(&:created_at),
        *approval_project_rules.map(&:created_at)
      ].min
    end

    def updated_at
      [
        *external_status_checks.map(&:updated_at),
        *approval_project_rules.map(&:updated_at)
      ].max
    end
  end
end
