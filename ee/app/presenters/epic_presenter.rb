# frozen_string_literal: true

class EpicPresenter < Gitlab::View::Presenter::Delegated
  include GitlabRoutingHelper
  include EntityDateHelper
  include Gitlab::Utils::StrongMemoize

  delegator_override_with Gitlab::Utils::StrongMemoize
  presents ::Epic, as: :epic

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
end
