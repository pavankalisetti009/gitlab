# frozen_string_literal: true

module RemoteDevelopment
  class WorkspaceAgentkState < ApplicationRecord
    belongs_to :workspace, inverse_of: :agentk_state
    belongs_to :project, inverse_of: :workspace_agentk_states

    validates :workspace_id, presence: true
    validates :project_id, presence: true
    validates :desired_config, presence: true
  end
end
