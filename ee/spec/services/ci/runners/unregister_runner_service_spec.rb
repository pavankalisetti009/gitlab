# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::UnregisterRunnerService, '#execute', feature_category: :runner do
  let(:audit_service) { instance_double(::AuditEvents::UnregisterRunnerAuditEventService) }
  let(:current_user) { nil }
  let(:token) { 'abc123' }

  subject(:execute) { described_class.new(runner, current_user || token).execute }

  context 'on an instance runner' do
    let(:runner) { create(:ci_runner) }

    it 'logs an audit event with the instance scope' do
      expect(audit_service).to receive(:track_event).once.and_return('track_event_return_value')
      expect(::AuditEvents::UnregisterRunnerAuditEventService).to receive(:new)
        .with(runner, token, an_instance_of(::Gitlab::Audit::InstanceScope))
        .once.and_return(audit_service)

      execute
    end
  end

  context 'on a group runner' do
    let(:group) { create(:group) }
    let(:runner) { create(:ci_runner, :group, groups: [group]) }
    let(:current_user) { build(:user) }

    it 'logs an audit event with the group scope' do
      expect(audit_service).to receive(:track_event).once.and_return('track_event_return_value')
      expect(::AuditEvents::UnregisterRunnerAuditEventService).to receive(:new)
        .with(runner, current_user, group)
        .once.and_return(audit_service)

      execute
    end
  end

  context 'on a project runner' do
    let(:projects) { create_list(:project, 2) }
    let(:runner) { create(:ci_runner, :project, projects: projects) }

    it 'logs an audit event for each project' do
      expect(audit_service).to receive(:track_event).twice.and_return('track_event_return_value')
      projects.each do |project|
        expect(::AuditEvents::UnregisterRunnerAuditEventService).to receive(:new)
          .with(runner, token, project)
          .once.and_return(audit_service)
      end

      execute
    end
  end
end
