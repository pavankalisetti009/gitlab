# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts, Gitlab/NamespacedClass -- Will be decided on after https://gitlab.com/groups/gitlab-org/-/epics/16894 is finalized
class GroupPushRule < ApplicationRecord
  include PushRuleable

  belongs_to :group, optional: false

  delegate :organization, to: :group

  def available?(feature_sym, object: nil) # rubocop:disable Lint/UnusedMethodArgument -- `object` is unused here but required for interface compatibility
    group.licensed_feature_available?(feature_sym)
  end

  def global?
    false
  end
end
# rubocop:enable Gitlab/BoundedContexts, Gitlab/NamespacedClass -- Will be decided on after https://gitlab.com/groups/gitlab-org/-/epics/16894 is finalized
