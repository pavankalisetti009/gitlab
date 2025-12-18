# frozen_string_literal: true

module SecretsManagement
  class GroupSecretsManager < BaseSecretsManager
    include GroupSecretsManagers::PipelineHelper
    include GroupSecretsManagers::UserHelper

    self.table_name = 'group_secrets_managers'

    belongs_to :group, inverse_of: :secrets_manager

    validates :group, presence: true

    before_create :set_group_path

    def root_namespace_path
      gid = group.parent ? group.root_ancestor.id : group.id

      "group_#{gid}"
    end

    def full_group_namespace_path
      [root_namespace_path, group_path].join('/')
    end

    private

    def set_group_path
      self.group_path = "group_#{group.id}"
    end
  end
end
