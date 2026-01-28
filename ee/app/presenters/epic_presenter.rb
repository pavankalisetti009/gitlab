# frozen_string_literal: true

class EpicPresenter < Gitlab::View::Presenter::Delegated
  include GitlabRoutingHelper
  include EntityDateHelper
  include Gitlab::Utils::StrongMemoize

  delegator_override_with Gitlab::Utils::StrongMemoize
  presents ::Epic, as: :epic

  def show_data(base_data: {}, author_icon: nil)
    {
      initial: initial_data.merge(base_data).to_json,
      meta: meta_data(author_icon).to_json
    }
  end

  def group_epic_path
    url_builder.build(epic, only_path: true)
  end

  def group_epic_url
    url_builder.build(epic)
  end

  def epic_reference(full: false)
    if full
      epic.to_reference(full: true)
    else
      epic.to_reference(epic.parent&.group || epic.group)
    end
  end

  delegator_override :subscribed?
  def subscribed?
    return false if current_user.blank?

    epic.subscribed?(current_user)
  end

  # With the new WorkItem structure the logic for the "inherited"/"fixed" dates changed
  # To ensure we're using the same values on the new UI/APIs and on the legacy (like Roadmaps)
  # we overwrite the *_date* methods to use the logic from WorkItems::StartAndDueDate
  # We also read other attributes from work_item to ensure consistency
  delegator_override :start_date,
    :start_date_fixed,
    :start_date_is_fixed,
    :start_date_is_fixed?,
    :start_date_from_milestones,
    :due_date,
    :due_date_fixed,
    :due_date_is_fixed,
    :due_date_is_fixed?,
    :due_date_from_milestones,
    :created_at,
    :updated_at,
    :state,
    :lock_version,
    :labels,
    :author,
    :confidential,
    :confidential?,
    :color,
    :text_color,
    :title,
    :description

  def start_date
    rollupable_dates.start_date
  end
  alias_method :start_date_fixed, :start_date

  def due_date
    rollupable_dates.due_date
  end
  alias_method :due_date_fixed, :due_date

  def start_date_is_fixed?
    rollupable_dates.fixed?
  end
  alias_method :due_date_is_fixed?, :start_date_is_fixed?

  def work_item_id
    epic.issue_id
  end

  def created_at
    work_item.created_at
  end

  def state
    work_item.state
  end

  def lock_version
    work_item.lock_version
  end

  def labels
    work_item.labels
  end

  def author
    work_item.author
  end

  def updated_at
    work_item.updated_at
  end

  def confidential
    work_item.confidential
  end
  alias_method :confidential?, :confidential

  def color
    work_item.color&.color.to_s
  end

  def text_color
    work_item.color&.text_color.to_s
  end

  def title
    work_item.title
  end

  def description
    work_item.description
  end

  def start_date_from_milestones
    rollupable_dates.start_date
  end

  def due_date_from_milestones
    rollupable_dates.due_date
  end

  private

  def work_item
    epic.work_item
  end
  strong_memoize_attr :work_item

  def rollupable_dates
    work_item.get_widget(:start_and_due_date)
  end
  strong_memoize_attr :rollupable_dates

  def initial_data
    { labels: labels }
  end

  def meta_data(author_icon)
    {}.tap do |hash|
      hash.merge!(base_attributes(author_icon))
      hash.merge!(endpoints)
      hash.merge!(start_dates)
      hash.merge!(due_dates)
    end
  end

  def base_attributes(author_icon)
    {
      epic_id: epic.id,
      epic_iid: epic.iid,
      created: created_at,
      author: epic_author(author_icon),
      ancestors: epic_ancestors(epic.ancestors.inc_group),
      reference: epic.to_reference(full: true),
      todo_exists: epic_pending_todo.present?,
      todo_path: group_todos_path(group),
      lock_version: lock_version,
      state: state,
      scoped_labels: group.licensed_feature_available?(:scoped_labels)
    }
  end

  def endpoints
    paths = {
      namespace: group.path,
      labels_path: group_labels_path(group, format: :json, only_group_labels: true, include_ancestor_groups: true),
      toggle_subscription_path: toggle_subscription_group_epic_path(group, epic),
      labels_web_url: group_labels_path(group),
      epics_web_url: group_epics_path(group),
      new_epic_web_url: new_group_epic_path(group),
      web_url: group_epic_url
    }

    paths[:todo_delete_path] = dashboard_todo_path(epic_pending_todo) if epic_pending_todo.present?

    paths
  end

  # todo:
  #
  # rename the hash keys to something more like inherited_source rather than milestone
  # as now source can be both milestone and child epic, but it does require a bunch of renaming on frontend as well
  def start_dates
    {
      start_date: start_date,
      start_date_is_fixed: start_date_is_fixed?,
      start_date_fixed: start_date_fixed,
      start_date_from_milestones: epic.start_date_from_inherited_source,
      start_date_sourcing_milestone_title: epic.start_date_from_inherited_source_title,
      start_date_sourcing_milestone_dates: {
        start_date: epic.start_date_from_inherited_source,
        due_date: epic.due_date_from_inherited_source
      }
    }
  end

  # todo:
  # same renaming applies here
  def due_dates
    {
      due_date: due_date,
      due_date_is_fixed: due_date_is_fixed?,
      due_date_fixed: due_date_fixed,
      due_date_from_milestones: epic.due_date_from_inherited_source,
      due_date_sourcing_milestone_title: epic.due_date_from_inherited_source_title,
      due_date_sourcing_milestone_dates: {
        start_date: epic.start_date_from_inherited_source,
        due_date: epic.due_date_from_inherited_source
      }
    }
  end

  def epic_pending_todo
    current_user.pending_todo_for(epic) if current_user
  end

  def epic_author(author_icon)
    {
      id: author.id,
      name: author.name,
      url: user_path(author),
      username: "@#{author.username}",
      src: author_icon
    }
  end

  def epic_ancestors(epics)
    epics.map do |epic|
      {
        id: epic.id,
        title: epic.title,
        url: url_builder.epic_path(epic),
        state: epic.state,
        human_readable_end_date: due_date&.to_fs(:medium),
        human_readable_timestamp: remaining_days_in_words(due_date, start_date)
      }
    end
  end
end
