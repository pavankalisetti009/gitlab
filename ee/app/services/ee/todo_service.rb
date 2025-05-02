# frozen_string_literal: true

module EE
  module TodoService
    extend ::Gitlab::Utils::Override

    def duo_pro_access_granted(user)
      attributes = {
        target_id: user.id,
        target_type: ::User,
        action: ::Todo::DUO_PRO_ACCESS_GRANTED,
        author_id: user.id
      }
      create_todos(user, attributes, nil, nil)
    end

    def duo_enterprise_access_granted(user)
      attributes = {
        target_id: user.id,
        target_type: ::User,
        action: ::Todo::DUO_ENTERPRISE_ACCESS_GRANTED,
        author_id: user.id
      }
      create_todos(user, attributes, nil, nil)
    end

    def update_epic(epic, current_user, skip_users = [])
      update_issuable(epic, current_user, skip_users)
    end

    # When a merge train is aborted for some reason, we should:
    #
    #  * create a todo for each merge request participant
    #
    def merge_train_removed(merge_request)
      merge_request.merge_participants.each do |user|
        create_merge_train_removed_todo(merge_request, user)
      end
    end

    def request_okr_checkin(work_item, assignee)
      project = work_item.project

      attributes = attributes_for_todo(project, work_item, work_item.author, ::Todo::OKR_CHECKIN_REQUESTED)

      create_todos(assignee, attributes, project.namespace, project)
    end

    def added_approver(users, merge_request)
      project = merge_request.project
      attributes = attributes_for_todo(project, merge_request, merge_request.author, ::Todo::ADDED_APPROVER)

      create_todos(users, attributes, project.namespace, project)
    end

    private

    override :attributes_for_target
    def attributes_for_target(target)
      attributes = super

      if target.is_a?(Epic)
        attributes[:group_id] = target.group_id
      elsif target.is_a?(WikiPage::Meta)
        attributes[:group_id] = target.namespace_id
      end

      attributes
    end

    def create_merge_train_removed_todo(merge_request, user)
      project = merge_request.project
      attributes = attributes_for_todo(project, merge_request, user, ::Todo::MERGE_TRAIN_REMOVED)
      create_todos(user, attributes, project.namespace, project)
    end
  end
end
