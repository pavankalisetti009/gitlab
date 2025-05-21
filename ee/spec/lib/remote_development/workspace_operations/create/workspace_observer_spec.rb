# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::WorkspaceObserver, feature_category: :workspaces do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group, developers: user) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let(:context) do
    {
      user: user,
      internal_events_class: Gitlab::InternalEvents,
      params: {
        project: project
      }
    }
  end

  describe '.observe' do
    it 'tracks a succeeded event and increases succeed metric' do
      expect { described_class.observe(context) }
        .to trigger_internal_events('create_workspace_result')
        .with(user: user, project: project, additional_properties: { label: 'succeed' })
        .and increment_usage_metrics('counts.count_total_succeed_workspaces_created')
    end
  end
end
