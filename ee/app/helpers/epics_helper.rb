# frozen_string_literal: true

module EpicsHelper
  def epic_initial_data(epic)
    issuable_initial_data(epic).merge(canCreate: can?(current_user, :create_epic, epic.group))
  end

  def epic_show_app_data(epic)
    EpicPresenter.new(epic, current_user: current_user).show_data(author_icon: avatar_icon_for_user(epic.author), base_data: epic_initial_data(epic))
  end

  def award_emoji_epics_api_path(epic)
    api_v4_groups_epics_award_emoji_path(id: epic.group.id, epic_iid: epic.iid)
  end
end

EpicsHelper.prepend_mod
