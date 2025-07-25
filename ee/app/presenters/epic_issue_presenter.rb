# frozen_string_literal: true

class EpicIssuePresenter < Gitlab::View::Presenter::Delegated
  delegator_override :issue
  presents ::EpicIssue, as: :issue

  def group_epic_issue_path(current_user)
    return unless can_admin_issue_link?(current_user)

    "#{group_epic_path(issue.epic.group, issue.epic.iid)}/issues/#{issue.epic_issue_id}"
  end

  private

  def can_admin_issue_link?(current_user)
    Ability.allowed?(current_user, :admin_issue_relation, issue) &&
      Ability.allowed?(current_user, :admin_epic_relation, issue.epic)
  end
end
