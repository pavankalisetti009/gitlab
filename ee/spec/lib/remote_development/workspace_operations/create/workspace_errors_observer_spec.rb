# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::WorkspaceErrorsObserver, feature_category: :workspaces do
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

  let(:message) do
    RemoteDevelopment::Messages::WorkspaceCreateDevfileLoadFailed.new(
      details: "Devfile could not be loaded from project",
      context: context
    )
  end

  describe '.observe' do
    let(:err_message) { message.class.name.demodulize  }

    it 'tracks a failed event with the error class and increases failure metric' do
      expect { described_class.observe(message) }
        .to trigger_internal_events('create_workspace_result')
        .with(user: user, project: project, additional_properties: { label: 'failed',
                                                                     property: err_message })
        .and increment_usage_metrics('counts.count_total_failed_workspaces_created')
    end
  end
end
