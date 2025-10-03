# frozen_string_literal: true

# rubocop:disable Gitlab/NamespacedClass -- No relevant product domain exists
class GroupPushRuleFinder # rubocop:disable Gitlab/BoundedContexts -- Will be decided on after https://gitlab.com/groups/gitlab-org/-/epics/16894 is finalized
  def initialize(group)
    @group = group
  end

  def execute
    group_push_rule
  end

  private

  attr_reader :group

  def group_push_rule
    if Feature.enabled?(:read_and_write_group_push_rules, group)
      group.group_push_rule
    else
      group.push_rule
    end
  end
end
# rubocop:enable Gitlab/NamespacedClass -- No relevant product domain exists
