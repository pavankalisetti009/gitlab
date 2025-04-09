# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts, Gitlab/NamespacedClass -- Will be decided on after https://gitlab.com/groups/gitlab-org/-/epics/16894 is finalized
class GroupPushRule < ApplicationRecord
  belongs_to :group
end
# rubocop:enable Gitlab/BoundedContexts, Gitlab/NamespacedClass -- Will be decided on after https://gitlab.com/groups/gitlab-org/-/epics/16894 is finalized
