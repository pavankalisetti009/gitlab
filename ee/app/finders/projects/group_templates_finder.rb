# frozen_string_literal: true

module Projects
  class GroupTemplatesFinder
    include Gitlab::Utils::StrongMemoize

    def initialize(user, group_id)
      @user = user
      @group_id = group_id
    end

    def execute
      return Project.none unless templates_available?

      ::Project
        .in_namespace(template_groups)
        .not_aimed_for_deletion
        .non_archived
        .with_route
        .projects_order_namespace_id_asc
        .with_order_id_asc
    end

    private

    attr_reader :user, :group_id

    def group
      Group.with_route.find_by_id(group_id)
    end
    strong_memoize_attr :group

    def templates_available?
      group && user.can?(:create_projects, group) && group.group_project_template_available?
    end

    def template_groups
      group.self_and_ancestors.with_project_templates.select(:custom_project_templates_group_id)
    end
  end
end
