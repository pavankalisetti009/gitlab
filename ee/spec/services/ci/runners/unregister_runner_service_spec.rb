# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::UnregisterRunnerService, '#execute', feature_category: :runner do
  let(:audit_service) { instance_double(::AuditEvents::RunnerAuditEventService) }
  let(:current_user) { nil }
  let(:token) { 'abc123' }
  let(:expected_message) do
    if runner.contacted_at.nil?
      s_('Runners|Unregistered %{runner_type} CI runner, never contacted')
    else
      s_('Runners|Unregistered %{runner_type} CI runner, last contacted %{runner_contacted_at}')
    end
  end

  let(:common_kwargs) do
    {
      name: 'ci_runner_unregistered',
      message: expected_message,
      runner_contacted_at: runner.contacted_at
    }
  end

  subject(:execute) { described_class.new(runner, current_user || token).execute }

  context 'on an instance runner' do
    let(:runner) { create(:ci_runner) }

    it 'logs an audit event with the instance scope' do
      expect(audit_service).to receive(:track_event).once
      expect(::AuditEvents::RunnerAuditEventService).to receive(:new)
        .with(runner, token, an_instance_of(::Gitlab::Audit::InstanceScope), **common_kwargs)
        .and_return(audit_service)

      execute
    end
  end

  context 'on a group runner' do
    let(:group) { create(:group) }
    let(:runner) { create(:ci_runner, :group, groups: [group]) }
    let(:current_user) { build(:user) }

    it 'logs an audit event with the group scope' do
      expect(audit_service).to receive(:track_event)
      expect(::AuditEvents::RunnerAuditEventService).to receive(:new)
        .with(runner, current_user, group, **common_kwargs)
        .and_return(audit_service)

      execute
    end
  end

  context 'on a project runner' do
    let(:projects) { create_list(:project, 2) }
    let(:runner) { create(:ci_runner, :project, projects: projects) }

    it 'logs an audit event for each project' do
      expect(audit_service).to receive(:track_event).twice
      projects.each do |project|
        expect(::AuditEvents::RunnerAuditEventService).to receive(:new)
          .with(runner, token, project, **common_kwargs)
          .and_return(audit_service)
      end

      execute
    end
  end
end
